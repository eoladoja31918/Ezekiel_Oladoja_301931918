-- MIT 8103 Portfolio 2: capture ALL baseline plans in one Neon execution.
-- Prerequisites: schema.sql and generate-data.sql succeeded.
-- Run the ENTIRE file in one SQL Editor execution on the same database.
-- Executes four read-only clinic queries, three times each (12 executions).
-- No clinic data or indexes are changed. Temporary tables store measurements.
-- The LAST statement returns all 12 plans so Neon can show one result grid.
-- Do not select isolated statements; execute the complete script at once.

BEGIN ISOLATION LEVEL READ COMMITTED;
SET LOCAL TIME ZONE 'Africa/Lagos';

-- These names are reserved for this script, in the temporary session schema.
DROP TABLE IF EXISTS pg_temp.p2_baseline_queries;
DROP TABLE IF EXISTS pg_temp.p2_baseline_results;

CREATE TEMP TABLE p2_baseline_queries (
    query_number INTEGER PRIMARY KEY,
    query_name TEXT NOT NULL,
    query_text TEXT NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE p2_baseline_results (
    query_number INTEGER,
    query_name TEXT,
    run_number INTEGER,
    captured_at TIMESTAMPTZ,
    planning_time_ms NUMERIC,
    execution_time_ms NUMERIC,
    returned_rows BIGINT,
    full_plan JSONB
) ON COMMIT PRESERVE ROWS;

INSERT INTO p2_baseline_queries VALUES
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
    (3, 'Q3 Pending laboratory tests', $query$SELECT
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
LIMIT 50$query$),
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

DO $$
DECLARE
    q RECORD;
    run_no INTEGER;
    plan_document JSONB;
BEGIN
    -- Run Q1-Q4, then repeat the sequence twice.
    FOR run_no IN 1..3 LOOP
        FOR q IN SELECT * FROM p2_baseline_queries ORDER BY query_number LOOP
            EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ' || q.query_text
            INTO plan_document;
            INSERT INTO p2_baseline_results VALUES (
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
       jsonb_pretty(full_plan) AS full_plan
FROM pg_temp.p2_baseline_results
ORDER BY query_number,run_number;

-- The temporary result table lasts only for this database session.
-- Save/export this grid before leaving or running another capture.
-- These are baseline measurements, not proof that optimisation is needed.
-- Cache and Neon compute wake-up affect timings; label run 1 separately.
-- Keep the same dataset, date window and compute settings for later comparison.
-- This captures plans, not ordinary query-result records; keep separate query
-- result evidence from queries.sql as required by the assessment.
-- If any statement fails, run ROLLBACK; and share the error before retrying.
