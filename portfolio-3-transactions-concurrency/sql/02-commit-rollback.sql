-- Run after 01-setup.sql. Run once; repeat bookings would conflict.
-- A valid transaction saves an appointment AND its diagnosis together.
BEGIN;
WITH booking AS (
    INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time,status)
    SELECT p.patient_id,d.doctor_id,'2035-01-10 09:00+01','2035-01-10 09:30+01','scheduled'
    FROM clinic.patients p CROSS JOIN clinic.doctors d
    WHERE p.patient_number='P3-P-01' AND d.doctor_number='P3-D-01'
    RETURNING appointment_id
)
INSERT INTO clinic.diagnoses(appointment_id,diagnosis_description)
SELECT appointment_id,'Synthetic note for transaction demonstration' FROM booking;
COMMIT;

-- A second valid appointment is deliberately discarded using ROLLBACK.
BEGIN;
INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time,status)
SELECT p.patient_id,d.doctor_id,'2035-01-10 09:30+01','2035-01-10 10:00+01','scheduled'
FROM clinic.patients p CROSS JOIN clinic.doctors d
WHERE p.patient_number='P3-P-01' AND d.doctor_number='P3-D-01';
-- At this point the current session can see its uncommitted appointment.
SELECT appointment_id,start_time,status FROM clinic.appointments
WHERE doctor_id=(SELECT doctor_id FROM clinic.doctors WHERE doctor_number='P3-D-01')
  AND start_time='2035-01-10 09:30+01'::timestamptz;
ROLLBACK;

-- Expected: one committed appointment with its note, and zero rolled-back ones.
SELECT 'COMMIT: booking and note persisted' AS check_name,
       count(*) AS actual_rows, 1 AS expected_rows
FROM clinic.appointments a JOIN clinic.diagnoses dx USING(appointment_id)
JOIN clinic.doctors d USING(doctor_id)
WHERE d.doctor_number='P3-D-01'
  AND a.start_time='2035-01-10 09:00+01'::timestamptz
  AND dx.diagnosis_description='Synthetic note for transaction demonstration'
UNION ALL
SELECT 'ROLLBACK: second booking absent',count(*),0
FROM clinic.appointments a JOIN clinic.doctors d USING(doctor_id)
WHERE d.doctor_number='P3-D-01' AND a.start_time='2035-01-10 09:30+01'::timestamptz;
