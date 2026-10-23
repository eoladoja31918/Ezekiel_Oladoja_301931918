-- MIT 8103 Portfolio 2: apply targeted optimisation and capture plans
-- Run this COMPLETE file once in the same Neon database as the baseline.
-- Adds three named indexes; does not edit patient or clinical records.
-- Q1/Q2/Q4 query text is unchanged; Q3 uses an equivalent limited queue CTE.
-- Captures four queries x three runs; final SELECT returns all 12 JSON plans.
-- Run only after saving your original baseline-plans.json.
-- Use the same dataset and compute configuration as your baseline.
-- Q2 uses a calendar-relative window: rerun baseline before indexing if the
-- Lagos date has changed since baseline collection, or use fixed matching bounds.
-- Index creation takes locks; this is for your educational clinic database.
-- This script intentionally fails on existing p2_ index names rather than
-- silently reusing an index that might have a different definition.
-- If execution fails before COMMIT, run ROLLBACK; and share the error.
-- If execution succeeds, do not rerun the whole file (indexes already exist).
-- To recapture after success, use the capture section without CREATE INDEX.
-- The final result-verification column is returned only after Q3 check passes.

BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL TIME ZONE 'Africa/Lagos';

-- Q2: B-tree matches doctor equality, time range, and requested ordering.
-- Restricting to scheduled rows keeps the index smaller than an all-row index.
CREATE INDEX p2_appointments_scheduled_doctor_time_idx
ON clinic.appointments (doctor_id, start_time, appointment_id)
INCLUDE (patient_id, end_time)
WHERE status='scheduled';

-- Q3: index the pending queue in oldest-first order.
CREATE INDEX p2_laboratory_pending_queue_idx
ON clinic.laboratory_requests (requested_at, request_id)
INCLUDE (appointment_id)
WHERE status='pending';

-- Q3: retrieve pending items in request-item order for each request.
CREATE INDEX p2_laboratory_pending_items_idx
ON clinic.laboratory_request_items (request_id, request_item_id)
INCLUDE (test_id)
WHERE status='pending';

-- Refresh planner statistics. Index creation also warms caches; compare with
-- the repeated baseline runs, not only the baseline first-run measurements.
ANALYZE clinic.appointments;
ANALYZE clinic.laboratory_requests;
ANALYZE clinic.laboratory_request_items;


-- These names are reserved for this script, in the temporary session schema.
DROP TABLE IF EXISTS pg_temp.p2_optimised_queries;
DROP TABLE IF EXISTS pg_temp.p2_optimised_results;

CREATE TEMP TABLE p2_optimised_queries (
    query_number INTEGER PRIMARY KEY,
    query_name TEXT NOT NULL,
    query_text TEXT NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE p2_optimised_results (
    query_number INTEGER,
    query_name TEXT,
    run_number INTEGER,
    captured_at TIMESTAMPTZ,
    planning_time_ms NUMERIC,
    execution_time_ms NUMERIC,
    returned_rows BIGINT,
    full_plan JSONB
) ON COMMIT PRESERVE ROWS;

INSERT INTO p2_optimised_queries VALUES
    (1, 'Q1 Patient history', $query$SELECT
    p.patient_number,
    p.first_name,
    p.last_name,
    a.appointment_id,
    a.start_time AT TIME ZONE 'Africa/Lagos' AS appointment_time_wat,
    a.status,
    d.full_name AS doctor_name,
    d.specialisation,
    COALESCE(
        (SELECT string_agg(dx.diagnosis_description, '; ' ORDER BY dx.diagnosis_id)
         FROM clinic.diagnoses dx
         WHERE dx.appointment_id=a.appointment_id),
        'No diagnosis recorded'
    ) AS diagnoses
FROM clinic.patients p
JOIN clinic.appointments a ON a.patient_id=p.patient_id
JOIN clinic.doctors d ON d.doctor_id=a.doctor_id
WHERE p.patient_number='P2-P-00002'
ORDER BY a.start_time DESC,a.appointment_id DESC$query$),
    (2, 'Q2 Doctor schedule', $query$SELECT
    d.doctor_number,
    d.full_name AS doctor_name,
    a.appointment_id,
    p.patient_number,
    p.first_name,
    p.last_name,
    a.start_time AT TIME ZONE 'Africa/Lagos' AS start_time_wat,
    a.end_time AT TIME ZONE 'Africa/Lagos' AS end_time_wat,
    a.status
FROM clinic.appointments a
JOIN clinic.doctors d ON d.doctor_id=a.doctor_id
JOIN clinic.patients p ON p.patient_id=a.patient_id
WHERE d.doctor_number='P2-D-01'
  AND a.status='scheduled'
  AND a.start_time >= (
      (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Lagos')::date::timestamp
      AT TIME ZONE 'Africa/Lagos'
  )
  AND a.start_time < (
      ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Lagos')::date + 30)::timestamp
      AT TIME ZONE 'Africa/Lagos'
  )
ORDER BY a.start_time,a.appointment_id$query$),
    (3, 'Q3 Pending laboratory tests', $query$WITH queue AS MATERIALIZED (
    SELECT lr.request_id, lr.requested_at, lr.appointment_id,
           lr.status AS request_status,
           li.request_item_id, li.test_id, li.status AS test_status
    FROM clinic.laboratory_requests lr
    JOIN clinic.laboratory_request_items li ON li.request_id=lr.request_id
    WHERE lr.status='pending' AND li.status='pending'
    ORDER BY lr.requested_at, lr.request_id, li.request_item_id
    LIMIT 50
)
SELECT q.request_id,
       q.requested_at AT TIME ZONE 'Africa/Lagos' AS requested_at_wat,
       p.patient_number, p.first_name, p.last_name,
       q.request_item_id, t.test_code, t.test_name,
       q.request_status, q.test_status
FROM queue q
JOIN clinic.appointments a ON a.appointment_id=q.appointment_id
JOIN clinic.patients p ON p.patient_id=a.patient_id
JOIN clinic.laboratory_tests t ON t.test_id=q.test_id
ORDER BY q.requested_at, q.request_id, q.request_item_id$query$),
    (4, 'Q4 Monthly summary', $query$SELECT
    date_trunc('month',a.start_time AT TIME ZONE 'Africa/Lagos')::date AS month_start,
    count(*) AS total_appointments,
    count(*) FILTER (WHERE a.status='completed') AS completed,
    count(*) FILTER (WHERE a.status='scheduled') AS scheduled,
    count(*) FILTER (WHERE a.status='cancelled') AS cancelled,
    count(*) FILTER (WHERE a.status='no-show') AS no_show
FROM clinic.appointments a
GROUP BY date_trunc('month',a.start_time AT TIME ZONE 'Africa/Lagos')::date
ORDER BY month_start$query$);


-- The rewrite limits the ordered queue before looking up descriptive details.
-- Mandatory, valid foreign keys and unique parent keys make those lookups
-- one-to-one and non-filtering, so they do not alter queue membership.
-- Verify both directions with EXCEPT ALL (preserves duplicate multiplicity).
-- REPEATABLE READ ensures verification and capture share a stable snapshot.
DO $verify$
DECLARE differences BIGINT;
BEGIN
    WITH original AS MATERIALIZED (
SELECT
    lr.request_id,
    lr.requested_at AT TIME ZONE 'Africa/Lagos' AS requested_at_wat,
    p.patient_number,
    p.first_name,
    p.last_name,
    li.request_item_id,
    t.test_code,
    t.test_name,
    lr.status AS request_status,
    li.status AS test_status
FROM clinic.laboratory_requests lr
JOIN clinic.appointments a ON a.appointment_id=lr.appointment_id
JOIN clinic.patients p ON p.patient_id=a.patient_id
JOIN clinic.laboratory_request_items li ON li.request_id=lr.request_id
JOIN clinic.laboratory_tests t ON t.test_id=li.test_id
WHERE lr.status='pending'
  AND li.status='pending'
ORDER BY lr.requested_at,lr.request_id,li.request_item_id
LIMIT 50
    ), rewritten AS MATERIALIZED (
WITH queue AS MATERIALIZED (
    SELECT lr.request_id, lr.requested_at, lr.appointment_id,
           lr.status AS request_status,
           li.request_item_id, li.test_id, li.status AS test_status
    FROM clinic.laboratory_requests lr
    JOIN clinic.laboratory_request_items li ON li.request_id=lr.request_id
    WHERE lr.status='pending' AND li.status='pending'
    ORDER BY lr.requested_at, lr.request_id, li.request_item_id
    LIMIT 50
)
SELECT q.request_id,
       q.requested_at AT TIME ZONE 'Africa/Lagos' AS requested_at_wat,
       p.patient_number, p.first_name, p.last_name,
       q.request_item_id, t.test_code, t.test_name,
       q.request_status, q.test_status
FROM queue q
JOIN clinic.appointments a ON a.appointment_id=q.appointment_id
JOIN clinic.patients p ON p.patient_id=a.patient_id
JOIN clinic.laboratory_tests t ON t.test_id=q.test_id
ORDER BY q.requested_at, q.request_id, q.request_item_id
    )
    SELECT count(*) INTO differences
    FROM (
        (SELECT * FROM original EXCEPT ALL SELECT * FROM rewritten)
        UNION ALL
        (SELECT * FROM rewritten EXCEPT ALL SELECT * FROM original)
    ) AS discrepancies;
    IF differences <> 0 THEN
        RAISE EXCEPTION 'Q3 equivalence FAILED: % differing rows; optimisation rolled back',differences;
    END IF;
END;
$verify$;

DO $$
DECLARE
    q RECORD;
    run_no INTEGER;
    plan_document JSONB;
BEGIN
    -- Run Q1-Q4, then repeat the sequence twice.
    FOR run_no IN 1..3 LOOP
        FOR q IN SELECT * FROM p2_optimised_queries ORDER BY query_number LOOP
            EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || q.query_text
            INTO plan_document;
            INSERT INTO p2_optimised_results VALUES (
                q.query_number,q.query_name,run_no,clock_timestamp(),
                (plan_document->0->>'Planning Time')::numeric,
                (plan_document->0->>'Execution Time')::numeric,
                (plan_document->0->'Plan'->>'Actual Rows')::numeric::bigint,
                plan_document
            );
        END LOOP;
    END LOOP;
END;
$$;
COMMIT;

-- Final result: twelve rows containing timings AND complete execution plans.
-- Expand each full_plan cell or export the grid as CSV/JSON immediately.
-- A screenshot of timings alone does not replace saving the full plans.
SELECT query_number,query_name,run_number,captured_at,
       planning_time_ms,execution_time_ms,returned_rows,
       'PASS: Q3 equivalent before capture' AS result_verification,
       jsonb_pretty(full_plan) AS full_plan
FROM pg_temp.p2_optimised_results
ORDER BY query_number,run_number;

-- Export the full 12-row grid as optimised-plans.json before leaving.
-- Retain the original baseline-plans.json without edits.
-- Returned row counts should match the baseline (6, 250, 50, 8) if the
-- dataset and Q2 calendar window have not changed; row counts alone do not
-- prove equality, so the Q3 check above compares complete rows.
-- This file changes Q3 and indexes together; it measures their combined effect.
-- Q1 and Q4 are unchanged controls. No speed improvement is claimed in advance.
-- Index storage and write-maintenance costs must be discussed in the analysis.
-- Optional size inspection (run separately after exporting):
-- SELECT indexname, pg_size_pretty(pg_relation_size(
--   format('%I.%I',schemaname,indexname)::regclass)) AS index_size
-- FROM pg_indexes WHERE schemaname='clinic' AND indexname LIKE 'p2_%';
