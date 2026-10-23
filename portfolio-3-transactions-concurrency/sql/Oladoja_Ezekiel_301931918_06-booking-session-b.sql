-- B1: independent connection; check before starting.
SELECT pg_backend_pid() AS session_b_pid;

-- B2: run AFTER A2 and BEFORE A3.
BEGIN ISOLATION LEVEL READ COMMITTED;
-- Prevent an indefinitely abandoned wait. Run A3 within two minutes.
SET LOCAL lock_timeout='120s';
INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time,status)
SELECT p.patient_id,d.doctor_id,'2035-02-01 09:15+01','2035-02-01 09:45+01','scheduled'
FROM clinic.patients p CROSS JOIN clinic.doctors d
WHERE p.patient_number='P3-P-02' AND d.doctor_number='P3-D-01'
RETURNING appointment_id,start_time,end_time;
-- It should wait for A. Switch to A and run A3.
-- Expected after A commits: ERROR conflicting key violates exclusion constraint
-- doctor_schedule_no_overlap (SQLSTATE 23P01).
-- Lock timeout (55P03) is NOT the expected result: it means A was not resolved.

-- B3: execute separately AFTER the expected error.
ROLLBACK;
