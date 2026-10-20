-- SESSION B: use a second independent interactive connection.
-- B1: verify this PID differs from Session A.
SELECT pg_backend_pid() AS session_b_pid;

-- B2: execute AFTER A2, BEFORE A3.
BEGIN ISOLATION LEVEL READ COMMITTED;
SHOW transaction_isolation;
SELECT full_name FROM clinic.doctors WHERE doctor_number='P3-D-01';
-- Expected BEFORE A commits: P3 Demo Doctor. Uncommitted changes are invisible.
-- Keep this transaction open. Session A must now execute A3 (COMMIT).

-- B3: execute AFTER A3, within the SAME Session B transaction.
SELECT full_name FROM clinic.doctors WHERE doctor_number='P3-D-01';
-- Expected AFTER A commits: P3 Doctor - committed change.
-- READ COMMITTED uses a new snapshot per statement: nonrepeatable reads allowed.
COMMIT;
