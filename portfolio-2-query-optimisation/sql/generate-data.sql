-- MIT 8103 Portfolio 2: synthetic performance dataset
-- Prerequisite: the Portfolio 1 clinic schema (schema.sql).
-- Paste this COMPLETE file into the same Neon database SQL Editor and Run.
-- Run once. Existing Portfolio 1 data and indexes are preserved.
-- No real patient information or clinical advice is included.
-- This is a dataset generator, not a performance benchmark.
-- Do not increase the size until this batch runs successfully.

BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL search_path = clinic, public;
SET LOCAL TIME ZONE 'Africa/Lagos';

-- Refuse to mix this batch with a previous or incomplete P2 batch.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM clinic.patients WHERE patient_number LIKE 'P2-P-%')
       OR EXISTS (SELECT 1 FROM clinic.doctors WHERE doctor_number LIKE 'P2-D-%')
       OR EXISTS (SELECT 1 FROM clinic.laboratory_tests WHERE test_code LIKE 'P2-T-%') THEN
        RAISE EXCEPTION 'P2 batch identifiers already exist. Do not rerun this generator or delete existing work blindly.';
    END IF;
END;
$$;

-- 1. Create 5,000 patients with stable business identifiers.
INSERT INTO clinic.patients(patient_number, first_name, last_name, date_of_birth, phone, address)
SELECT 'P2-P-' || lpad(n::text,5,'0'),
       'DemoPatient' || n, 'Synthetic',
       DATE '1960-01-01' + ((n * 17) % 16000),
       NULL, 'Fictional district ' || (1 + n % 10)
FROM generate_series(1,5000) AS g(n);

-- 2. Create 20 doctors. Do not assume their generated IDs start at one.
INSERT INTO clinic.doctors(doctor_number, full_name, specialisation)
SELECT 'P2-D-' || lpad(n::text,2,'0'),
       'Demo Doctor ' || n,
       (ARRAY['General Medicine','Paediatrics','Cardiology','Dermatology'])[1 + (n-1)%4]
FROM generate_series(1,20) AS g(n);

-- 3. Add five dedicated catalogue tests.
INSERT INTO clinic.laboratory_tests(test_code,test_name,description)
VALUES ('P2-T-01','Demo Blood Panel','Synthetic dataset test'),
       ('P2-T-02','Demo Glucose Test','Synthetic dataset test'),
       ('P2-T-03','Demo Kidney Panel','Synthetic dataset test'),
       ('P2-T-04','Demo Liver Panel','Synthetic dataset test'),
       ('P2-T-05','Demo Urine Test','Synthetic dataset test');

-- 4. Plan six appointments per patient, 30,000 in total.
-- Visits 1-5 are historical; visit 6 is upcoming.
-- Each new doctor has ten half-hour slots per day, over 25 days per visit.
-- Assignment avoids overlapping scheduled appointments for doctor or patient.
CREATE TEMP TABLE p2_plan ON COMMIT DROP AS
SELECT p.patient_id, d.doctor_id, g.patient_no, g.visit_no,
       (CASE WHEN g.visit_no = 6
             THEN CURRENT_DATE + 1
             ELSE CURRENT_DATE - ((6-g.visit_no)*40)
        END + ((g.patient_no-1)/200) + TIME '08:00')
        AT TIME ZONE 'Africa/Lagos'
        + (((g.patient_no-1)/20)%10) * INTERVAL '30 minutes' AS starts_at,
       CASE WHEN g.visit_no = 6 THEN 'scheduled'
            WHEN g.patient_no%10 = 0 THEN 'cancelled'
            WHEN g.patient_no%10 = 1 THEN 'no-show'
            ELSE 'completed' END AS appointment_status
FROM (
    SELECT patient_no,visit_no
    FROM generate_series(1,5000) AS p(patient_no)
    CROSS JOIN generate_series(1,6) AS v(visit_no)
) AS g
JOIN clinic.patients p ON p.patient_number='P2-P-' || lpad(g.patient_no::text,5,'0')
JOIN clinic.doctors d ON d.doctor_number='P2-D-' || lpad((1+(g.patient_no-1)%20)::text,2,'0');

INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time,status)
SELECT patient_id,doctor_id,starts_at,starts_at+INTERVAL '30 minutes',appointment_status
FROM p2_plan;

-- Map generated appointment IDs back to the plan.
CREATE TEMP TABLE p2_appointments ON COMMIT DROP AS
SELECT a.appointment_id,p.*
FROM p2_plan p
JOIN clinic.appointments a ON a.patient_id=p.patient_id AND a.start_time=p.starts_at;
CREATE UNIQUE INDEX ON p2_appointments(appointment_id);

-- 5. One fictional diagnosis for each completed visit: 20,000 rows.
INSERT INTO clinic.diagnoses(appointment_id,diagnosis_description,recorded_at)
SELECT appointment_id,
       'Synthetic diagnosis category ' || (1+patient_no%8),
       starts_at + INTERVAL '10 minutes'
FROM p2_appointments WHERE appointment_status='completed';

-- 6. Create 3,000 prescription headers in draft state.
-- Eligible patients have numbers ending in 2 or 7 and completed visits 1-3.
INSERT INTO clinic.prescriptions(appointment_id,status)
SELECT appointment_id,'draft'
FROM p2_appointments
WHERE appointment_status='completed' AND visit_no<=3 AND patient_no%5=2;

CREATE TEMP TABLE p2_prescriptions ON COMMIT DROP AS
SELECT pr.prescription_id,a.starts_at
FROM clinic.prescriptions pr
JOIN p2_appointments a ON a.appointment_id=pr.appointment_id;

-- Two illustrative medication items per prescription: 6,000 rows.
INSERT INTO clinic.prescription_items(prescription_id,medication_name,dosage,frequency,duration)
SELECT p.prescription_id,'Demo medication ' || n,
       'Demo dose','Demo frequency','Demo duration'
FROM p2_prescriptions p CROSS JOIN generate_series(1,2) AS g(n);

UPDATE clinic.prescriptions pr
SET status='finalised',issued_at=p.starts_at+INTERVAL '20 minutes'
FROM p2_prescriptions p WHERE pr.prescription_id=p.prescription_id;

-- 7. Create 3,000 draft laboratory requests for another subset of visits.
INSERT INTO clinic.laboratory_requests(appointment_id,requested_at,status)
SELECT appointment_id,starts_at+INTERVAL '20 minutes','draft'
FROM p2_appointments
WHERE appointment_status='completed' AND visit_no<=3 AND patient_no%5=3;

CREATE TEMP TABLE p2_requests ON COMMIT DROP AS
SELECT r.request_id,a.patient_no,a.starts_at
FROM clinic.laboratory_requests r
JOIN p2_appointments a ON a.appointment_id=r.appointment_id;

-- One requested test per request: 3,000 items, half completed and half pending.
INSERT INTO clinic.laboratory_request_items(request_id,test_id,status)
SELECT r.request_id,t.test_id,
       CASE WHEN r.patient_no%2=0 THEN 'completed' ELSE 'pending' END
FROM p2_requests r
JOIN clinic.laboratory_tests t ON t.test_code='P2-T-' || lpad((1+r.request_id%5)::text,2,'0');

-- Two fictional measurements for each completed requested test: 3,000 results.
INSERT INTO clinic.laboratory_results(request_item_id,measurement_name,result_value,unit,reference_range,recorded_at)
SELECT li.request_item_id,'Demo measurement ' || n,
       (10+(r.patient_no%90)+n)::text,'demo-unit',NULL,
       r.starts_at+INTERVAL '2 hours'
FROM p2_requests r
JOIN clinic.laboratory_request_items li ON li.request_id=r.request_id
CROSS JOIN generate_series(1,2) AS g(n)
WHERE li.status='completed';

UPDATE clinic.laboratory_requests lr
SET status=CASE WHEN r.patient_no%2=0 THEN 'completed' ELSE 'pending' END
FROM p2_requests r WHERE lr.request_id=r.request_id;

-- 8. Verify actual batch counts. Abort if the generated dataset is incomplete.
CREATE TEMP TABLE p2_counts ON COMMIT DROP AS
SELECT 'patients'::text AS table_name,5000::bigint AS expected_rows,
       (SELECT count(*) FROM clinic.patients WHERE patient_number LIKE 'P2-P-%') AS actual_rows
UNION ALL SELECT 'doctors',20,(SELECT count(*) FROM clinic.doctors WHERE doctor_number LIKE 'P2-D-%')
UNION ALL SELECT 'appointments',30000,(SELECT count(*) FROM p2_appointments)
UNION ALL SELECT 'diagnoses',20000,(SELECT count(*) FROM clinic.diagnoses d JOIN p2_appointments a USING(appointment_id))
UNION ALL SELECT 'prescriptions',3000,(SELECT count(*) FROM p2_prescriptions)
UNION ALL SELECT 'prescription_items',6000,(SELECT count(*) FROM clinic.prescription_items i JOIN p2_prescriptions p USING(prescription_id))
UNION ALL SELECT 'laboratory_tests',5,(SELECT count(*) FROM clinic.laboratory_tests WHERE test_code LIKE 'P2-T-%')
UNION ALL SELECT 'laboratory_requests',3000,(SELECT count(*) FROM p2_requests)
UNION ALL SELECT 'laboratory_request_items',3000,(SELECT count(*) FROM clinic.laboratory_request_items i JOIN p2_requests r USING(request_id))
UNION ALL SELECT 'laboratory_results',3000,(SELECT count(*) FROM clinic.laboratory_results lr JOIN clinic.laboratory_request_items li USING(request_item_id) JOIN p2_requests r USING(request_id));

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM p2_counts WHERE expected_rows<>actual_rows) THEN
        RAISE EXCEPTION 'Generated row counts do not match expectations; batch rolled back.';
    END IF;
END;
$$;

-- Check deferred minimum-item rules BEFORE committing.
SET CONSTRAINTS ALL IMMEDIATE;

-- Refresh statistics used by the query planner. No indexes are added or removed.
ANALYZE clinic.patients;
ANALYZE clinic.doctors;
ANALYZE clinic.appointments;
ANALYZE clinic.diagnoses;
ANALYZE clinic.prescriptions;
ANALYZE clinic.prescription_items;
ANALYZE clinic.laboratory_tests;
ANALYZE clinic.laboratory_requests;
ANALYZE clinic.laboratory_request_items;
ANALYZE clinic.laboratory_results;

-- Keep this actual result grid as evidence. It should contain ten PASS rows.
-- Counts cover ONLY the P2 batch, excluding Portfolio 1 sample records.
SELECT table_name,expected_rows,actual_rows,
       CASE WHEN expected_rows=actual_rows THEN 'PASS' ELSE 'FAIL' END AS outcome
FROM p2_counts ORDER BY table_name;
COMMIT;

-- Ensure Neon reports successful completion/COMMIT, not just a partial result.
-- If an error leaves a failed transaction open, run ROLLBACK; before proceeding.
-- Do not rerun schema.sql. Do not run the generator a second time after success.
-- Save as portfolio-2-query-optimisation/sql/generate-data.sql.

