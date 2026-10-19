BEGIN;

SET LOCAL TIME ZONE 'Africa/Lagos';

DO $$
DECLARE
    v_patient_id      BIGINT;
    v_doctor_id       BIGINT;
    v_appointment_id  BIGINT;
    v_prescription_id BIGINT;
    v_test_id         BIGINT;
    v_request_id      BIGINT;
    v_request_item_id BIGINT;
BEGIN

    -- 1. Register a fictional patient.
    INSERT INTO clinic.patients (
        patient_number, first_name, last_name,
        date_of_birth, phone, address
    )
    VALUES (
        'PAT001', 'Amina', 'Bello',
        '1995-04-12', NULL, 'Fictional address, Lagos'
    )
    RETURNING patient_id INTO v_patient_id;

    -- 2. Register a fictional doctor.
    INSERT INTO clinic.doctors (
        doctor_number, full_name, specialisation
    )
    VALUES (
        'DOC001', 'Dr Ade Cole', 'General Medicine'
    )
    RETURNING doctor_id INTO v_doctor_id;

    -- 3. Record a completed appointment.
    INSERT INTO clinic.appointments (
        patient_id, doctor_id, start_time, end_time, status
    )
    VALUES (
        v_patient_id,
        v_doctor_id,
        '2026-10-19 09:00:00+01',
        '2026-10-19 09:30:00+01',
        'completed'
    )
    RETURNING appointment_id INTO v_appointment_id;

    -- 4. Record the diagnosis.
    INSERT INTO clinic.diagnoses (
        appointment_id, diagnosis_description, recorded_at
    )
    VALUES (
        v_appointment_id,
        'Example diagnosis: tension headache',
        '2026-10-19 09:15:00+01'
    );

    -- 5. Create a draft prescription.
    INSERT INTO clinic.prescriptions (
        appointment_id, status
    )
    VALUES (
        v_appointment_id, 'draft'
    )
    RETURNING prescription_id INTO v_prescription_id;

    -- 6. Add a fictional medication instruction.
    -- Educational sample data only.
    INSERT INTO clinic.prescription_items (
        prescription_id, medication_name,
        dosage, frequency, duration
    )
    VALUES (
        v_prescription_id,
        'Demo medication',
        'Demo dose',
        'Demo frequency',
        'Demo duration'
    );

    -- Finalise only after adding its medication item.
    UPDATE clinic.prescriptions
    SET status = 'finalised',
        issued_at = '2026-10-19 09:20:00+01'
    WHERE prescription_id = v_prescription_id;

    -- 7. Add a test to the laboratory catalogue.
    INSERT INTO clinic.laboratory_tests (
        test_code, test_name, description
    )
    VALUES (
        'FBC',
        'Full Blood Count',
        'Measures selected blood cell parameters'
    )
    RETURNING test_id INTO v_test_id;

    -- 8. Create a draft laboratory request.
    INSERT INTO clinic.laboratory_requests (
        appointment_id, requested_at, status
    )
    VALUES (
        v_appointment_id,
        '2026-10-19 09:20:00+01',
        'draft'
    )
    RETURNING request_id INTO v_request_id;

    -- 9. Attach the requested test.
    INSERT INTO clinic.laboratory_request_items (
        request_id, test_id, status
    )
    VALUES (
        v_request_id, v_test_id, 'pending'
    )
    RETURNING request_item_id INTO v_request_item_id;

    -- 10. Record two fictional result measurements.
    INSERT INTO clinic.laboratory_results (
        request_item_id, measurement_name,
        result_value, unit, reference_range, recorded_at
    )
    VALUES
        (
            v_request_item_id, 'Haemoglobin',
            '13.5', 'g/dL', NULL,
            '2026-10-19 11:00:00+01'
        ),
        (
            v_request_item_id, 'White blood cell count',
            '6.2', '10^9/L', NULL,
            '2026-10-19 11:00:00+01'
        );

    -- Mark the test and its request as completed.
    UPDATE clinic.laboratory_request_items
    SET status = 'completed'
    WHERE request_item_id = v_request_item_id;

    UPDATE clinic.laboratory_requests
    SET status = 'completed'
    WHERE request_id = v_request_id;

END;
$$;

COMMIT;

-- Verify the inserted records.
SELECT * FROM clinic.patients;
SELECT * FROM clinic.doctors;
SELECT * FROM clinic.appointments;
SELECT * FROM clinic.laboratory_results;
