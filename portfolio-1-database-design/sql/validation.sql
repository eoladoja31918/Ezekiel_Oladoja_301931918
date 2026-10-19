    RETURNING patient_id INTO patient_one;
    INSERT INTO clinic.patients(patient_number,first_name,last_name,date_of_birth)
    VALUES(token || 'P2','Validation','Patient Two','1992-01-01')
    RETURNING patient_id INTO patient_two;
    INSERT INTO clinic.doctors(doctor_number,full_name,specialisation)
    VALUES(token || 'D1','Validation Doctor One','General Medicine')
    RETURNING doctor_id INTO doctor_one;
    INSERT INTO clinic.doctors(doctor_number,full_name,specialisation)
    VALUES(token || 'D2','Validation Doctor Two','General Medicine')
    RETURNING doctor_id INTO doctor_two;

    INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time,status)
    VALUES(patient_one,doctor_one,'2030-01-15 09:00+01','2030-01-15 09:30+01','scheduled')
    RETURNING appointment_id INTO appointment_one;
    INSERT INTO pg_temp.validation_results(test_name,outcome,explanation)
    VALUES('Valid patient, doctor and appointment accepted','PASS','Fixture inserts succeeded.');

    -- UNIQUE: a second patient cannot use the same patient number.
    PERFORM pg_temp.expect_rejection('Duplicate patient number rejected',
        format('INSERT INTO clinic.patients(patient_number,first_name,last_name,date_of_birth) VALUES (%L,%L,%L,%L)',
               token || 'P1','Duplicate','Patient','1990-01-01'),
        '23505','patients_patient_number_key');

    -- FOREIGN KEY: choose an ID that does not exist, without assuming fixed IDs.
    SELECT candidate INTO missing_patient
    FROM generate_series(-1000::bigint,-1::bigint) AS g(candidate)
    WHERE NOT EXISTS (SELECT 1 FROM clinic.patients p WHERE p.patient_id=g.candidate)
    LIMIT 1;
    IF missing_patient IS NULL THEN
        RAISE EXCEPTION 'No unused negative patient ID available for this test';
    END IF;
    PERFORM pg_temp.expect_rejection('Nonexistent patient reference rejected',
        format('INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time) VALUES (%s,%s,%L,%L)',
               missing_patient,doctor_one,'2030-01-16 09:00+01','2030-01-16 09:30+01'),
        '23503','appointments_patient_id_fkey');

    -- CHECK: end time must be strictly later, so equal times are invalid.
    PERFORM pg_temp.expect_rejection('Zero-duration appointment rejected',
        format('INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time) VALUES (%s,%s,%L,%L)',
               patient_one,doctor_one,'2030-01-16 09:00+01','2030-01-16 09:00+01'),
        '23514','appointment_times_valid');

    -- EXCLUSION: different patient, same doctor, overlapping scheduled time.
    PERFORM pg_temp.expect_rejection('Doctor double booking rejected',
        format('INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time) VALUES (%s,%s,%L,%L)',
               patient_two,doctor_one,'2030-01-15 09:15+01','2030-01-15 09:45+01'),
        '23P01','doctor_schedule_no_overlap');

    -- EXCLUSION: same patient, different doctor, overlapping scheduled time.
    PERFORM pg_temp.expect_rejection('Patient double booking rejected',
        format('INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time) VALUES (%s,%s,%L,%L)',
               patient_one,doctor_two,'2030-01-15 09:15+01','2030-01-15 09:45+01'),
        '23P01','patient_schedule_no_overlap');

    -- Positive boundary case: the next appointment may start at the prior end.
    INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time)
    VALUES(patient_one,doctor_one,'2030-01-15 09:30+01','2030-01-15 10:00+01');
    INSERT INTO pg_temp.validation_results(test_name,outcome,explanation)
    VALUES('Adjacent non-overlapping appointments accepted','PASS','09:30 start follows 09:30 end.');

    -- NOT NULL: mandatory names cannot be omitted.
    PERFORM pg_temp.expect_rejection('Missing patient first name rejected',
        format('INSERT INTO clinic.patients(patient_number,first_name,last_name,date_of_birth) VALUES (%L,NULL,%L,%L)',
               token || 'NULL','Patient','1990-01-01'),
        '23502','first_name');

    -- CHECK: appointment status must be one of the documented values.
    PERFORM pg_temp.expect_rejection('Invalid appointment status rejected',
        format('INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time,status) VALUES (%s,%s,%L,%L,%L)',
               patient_one,doctor_one,'2030-01-17 09:00+01','2030-01-17 09:30+01','unknown'),
        '23514','appointment_status_valid');

    -- Trigger: a future birth date is invalid.
    PERFORM pg_temp.expect_rejection('Future birth date rejected',
        format('INSERT INTO clinic.patients(patient_number,first_name,last_name,date_of_birth) VALUES (%L,%L,%L,%L)',
               token || 'DOB','Future','Patient',
               (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Lagos')::date + 1),
        '23514','Date of birth must be finite and not in the future');

    -- First flush existing deferred events. Then make minimum-item triggers
    -- immediate so their errors can be caught inside individual test savepoints.
    -- A successful deferred creation workflow is tested separately via seed.sql.
    SET CONSTRAINTS ALL IMMEDIATE;

    -- issued_at is supplied, so rejection must be for missing items, not date.
    PERFORM pg_temp.expect_rejection('Finalised prescription without items rejected',
        format('INSERT INTO clinic.prescriptions(appointment_id,issued_at,status) VALUES (%s,CURRENT_TIMESTAMP,%L)',
               appointment_one,'finalised'),
        '23514','requires at least one item');

    PERFORM pg_temp.expect_rejection('Submitted laboratory request without tests rejected',
        format('INSERT INTO clinic.laboratory_requests(appointment_id,status) VALUES (%s,%L)',
               appointment_one,'pending'),
        '23514','requires at least one item');
END;
$$;

-- Screenshot/export this result grid BEFORE clearing the editor.
-- It contains actual results from your database, not pre-filled expected results.
SELECT test_number, test_name, outcome,
       expected_sqlstate, actual_sqlstate, explanation
FROM pg_temp.validation_results
ORDER BY test_number;

-- Neon may show only the last result grid, so the detailed grid above is the
-- only SELECT. Count its 12 rows and check every outcome is PASS.
ROLLBACK;

-- If any unexpected error stops execution, run ROLLBACK; before retrying.
-- Identity-number gaps are expected; existing records are not edited.
-- Save this file as portfolio-1-database-design/sql/validation.sql.
-- Save actual result screenshots/exports in portfolio-1-database-design/evidence/.

