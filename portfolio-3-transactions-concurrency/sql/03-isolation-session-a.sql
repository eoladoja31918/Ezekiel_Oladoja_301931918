-- SESSION A: execute each numbered section separately, following README.
-- A1: check connection identity. It must differ from session B.
SELECT pg_backend_pid() AS session_a_pid;

-- A2: start transaction and change a fictional doctor's name. DO NOT COMMIT YET.
BEGIN ISOLATION LEVEL READ COMMITTED;
UPDATE clinic.doctors SET full_name='P3 Doctor - committed change'
WHERE doctor_number='P3-D-01';
SELECT full_name FROM clinic.doctors WHERE doctor_number='P3-D-01';
-- Pause: Session B must now execute B1 and B2.

-- A3: run ONLY when Session B has observed the old name.
COMMIT;
-- Session B now executes B3 in its still-open transaction.
