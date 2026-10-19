-- MIT 8103 Portfolio 2: Query Processing and Optimisation
-- Run in Neon's SQL Editor against the existing clinic database.
-- Prerequisite: schema.sql and generate-data.sql completed successfully.
-- READ ONLY: these queries do not insert, update, delete, or create indexes.
-- Run ONE numbered query at a time so its result grid is easy to save.
-- Business identifiers are used; generated IDs are not assumed to start at 1.
--
-- BASELINE PROCEDURE:
-- 1. Run the SELECT normally and save its actual results.
-- 2. Add EXPLAIN (ANALYZE, BUFFERS) directly before that SELECT and rerun.
--    Equivalently, uncomment the EXPLAIN line already supplied per query.
-- 3. Save the full execution plan, including Planning Time and Execution Time.
-- 4. Repeat the plan three times; keep all times and identify the first run.
-- 5. Do not add indexes until all baseline plans have been captured.
-- EXPLAIN ANALYZE executes the SELECT; it displays a plan instead of result rows.
-- Existing Portfolio 1 indexes form part of the baseline.
-- Neon wake-up, cache state and compute size can affect comparisons.
-- Keep the same branch, compute settings and dataset for before/after runs.

-- =====================================================================
-- Q1. APPOINTMENT AND DIAGNOSIS HISTORY FOR ONE PATIENT
-- Shows all visits, including those without a diagnosis.
-- Expected P2-P-00002: six appointments (five completed, one scheduled),
-- provided the dataset has not changed since generation.
-- Full clinical history would also retrieve prescriptions and lab records;
-- joining every one-to-many child table directly would multiply rows.
-- =====================================================================
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
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
ORDER BY a.start_time DESC,a.appointment_id DESC;

-- =====================================================================
-- Q2. ONE DOCTOR'S UPCOMING SCHEDULE (NEXT 30 LAGOS CALENDAR DAYS)
-- Returns patient details for scheduled appointments, earliest first.
-- Date boundaries are calculated in Lagos time, independent of session zone.
-- Run baseline and optimised versions on the same day, or freeze the bounds
-- to the same explicit TIMESTAMPTZ literals in both versions.
-- =====================================================================
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
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
ORDER BY a.start_time,a.appointment_id;

-- =====================================================================
-- Q3. LABORATORY WORK QUEUE: OLDEST 50 PENDING REQUESTS
-- The oldest pending requests are listed first for operational follow-up.
-- This generator has one test per request. In the general schema, a request
-- containing multiple pending test items produces one row per pending item.
-- =====================================================================
-- EXPLAIN (ANALYZE, BUFFERS)
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
LIMIT 50;

-- =====================================================================
-- Q4. MONTHLY APPOINTMENT SUMMARY BY STATUS
-- Groups by Lagos calendar month, with each appointment counted once.
-- Includes Portfolio 1 records as well as the generated P2 batch.
-- This full-table aggregation may reasonably use a sequential scan.
-- An index should not be assumed to improve every query.
-- =====================================================================
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT
    date_trunc('month',a.start_time AT TIME ZONE 'Africa/Lagos')::date AS month_start,
    count(*) AS total_appointments,
    count(*) FILTER (WHERE a.status='completed') AS completed,
    count(*) FILTER (WHERE a.status='scheduled') AS scheduled,
    count(*) FILTER (WHERE a.status='cancelled') AS cancelled,
    count(*) FILTER (WHERE a.status='no-show') AS no_show
FROM clinic.appointments a
GROUP BY date_trunc('month',a.start_time AT TIME ZONE 'Africa/Lagos')::date
ORDER BY month_start;

-- EVIDENCE SUGGESTED NAMES:
-- evidence/query-results/q1-patient-history.png
-- evidence/query-results/q2-doctor-schedule.png
-- evidence/query-results/q3-pending-laboratory-tests.png
-- evidence/query-results/q4-monthly-summary.png
-- evidence/baseline-plans/q1-patient-history.txt (and similarly Q2-Q4)
-- Save actual plans, not only screenshots of the SQL statements.
-- Document timings, row counts, scan/join methods, sort operations and buffers.
-- Performance improvements will be measured later; none are claimed here.
