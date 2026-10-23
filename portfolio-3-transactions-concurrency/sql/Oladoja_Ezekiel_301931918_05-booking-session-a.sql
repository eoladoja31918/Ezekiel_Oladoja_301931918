-- Two-session race: use different patients, same doctor and overlapping times.
-- This tests doctor conflict specifically, not simultaneous patient conflict.
-- A1: confirm session identity; B must have a different PID.
SELECT pg_backend_pid() AS session_a_pid;

-- A2: insert, but DO NOT COMMIT until B is executing its competing INSERT.
BEGIN ISOLATION LEVEL READ COMMITTED;
INSERT INTO clinic.appointments(patient_id,doctor_id,start_time,end_time,status)
SELECT p.patient_id,d.doctor_id,'2035-02-01 09:00+01','2035-02-01 09:30+01','scheduled'
FROM clinic.patients p CROSS JOIN clinic.doctors d
WHERE p.patient_number='P3-P-01' AND d.doctor_number='P3-D-01'
RETURNING appointment_id,start_time,end_time;
-- Pause: Session B now executes B2; it should wait.

-- A3: run while B is waiting. A wins the booking.
COMMIT;
-- B should now receive exclusion violation SQLSTATE 23P01 and must ROLLBACK.
