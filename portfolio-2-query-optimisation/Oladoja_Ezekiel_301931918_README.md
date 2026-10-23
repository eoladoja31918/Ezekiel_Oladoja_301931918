# Portfolio 2: Query Processing and Optimisation

**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** Hospital / Clinic Management System  
**Platform:** PostgreSQL on Neon

## Objective

Evaluate clinic SQL queries using actual results and execution plans, apply justified optimisations, and compare performance while checking correctness. This builds on the normalised `clinic` schema from [Portfolio 1](../portfolio-1-database-design/README.md).

## Files and Assessment Evidence

| Requirement | File or folder |
|---|---|
| Synthetic performance dataset | [generate-data.sql](sql/generate-data.sql) |
| SQL queries | [queries.sql](sql/queries.sql) |
| Ordinary query results | [query-results](evidence/query-results/) |
| Baseline capture script | [capture-baselines.sql](sql/capture-baselines.sql) |
| Baseline execution plans | [baseline-plans.json](evidence/baseline-plans/baseline-plans.json) |
| Indexes, query rewrite, and optimised capture | [optimisation.sql](sql/optimisation.sql) |
| Optimised execution plans | [optimised-baseline-plans.json](evidence/optimised-plans/optimised-baseline-plans.json) |
| Performance analysis | [performance-comparison.md](analysis/performance-comparison.md) |

These files address the required SQL queries, query results, execution plans, optimisation evidence, and brief performance analysis. Upload each file at the linked path; links to evidence not yet uploaded will not resolve.

## Dataset

The generator adds 73,025 fictional records across ten tables, including 5,000 patients, 20 doctors, 30,000 appointments, 20,000 diagnoses, and related prescriptions and laboratory records. Existing Portfolio 1 sample data is retained. The captured monthly-summary plan scans 30,001 appointments, including the original sample appointment.

Generated patients, doctors, and test catalogue entries use `P2-` business identifiers. Appointments and related clinical records reference their actual generated IDs. No real patient data is used.

## Queries

| Query | Purpose | Rows returned in the captured runs |
|---|---|---:|
| Q1 | Patient appointment and diagnosis history | 6 |
| Q2 | One doctor's upcoming 30-day schedule | 250 |
| Q3 | Oldest 50 pending laboratory test items | 50 |
| Q4 | Monthly appointment totals by status | 8 |

Q1 aggregates diagnoses per appointment to avoid multiplying appointment rows. Q2 uses Lagos calendar boundaries. Q3 orders by request time and unique identifiers so the limited result is deterministic. Q4 counts appointments directly, without joins that could inflate totals.

## Setup and Execution in Neon

Use the same Neon branch and database containing the Portfolio 1 schema. PostgreSQL 14 or later and the existing `btree_gist` extension are prerequisites. Do not rerun `schema.sql` against an already-created schema.

In **SQL Editor**, paste the complete script and run it. Follow this order for a fresh reproduction:

1. Run `sql/generate-data.sql` once. Confirm successful completion and the generated row counts. It refuses a second batch using the same identifiers.
2. Run Q1–Q4 from `sql/queries.sql` individually, without `EXPLAIN`, and save their actual results under `evidence/query-results/`.
3. Run the corrected `sql/capture-baselines.sql` in full. Export its final 12-row grid, including `full_plan`, as `baseline-plans.json`.
4. Preserve that baseline export unchanged before applying any Portfolio 2 indexes.
5. Run `sql/optimisation.sql` once. It creates three indexes, verifies the Q3 rewrite, and captures another 12 plans. Export the complete final grid as `optimised-baseline-plans.json`.
6. Compare the exports using `analysis/performance-comparison.md`.

Each capture script executes four queries three times using `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`. The final grid includes planning time, execution time, returned row count, and the full plan. Temporary capture tables are session-scoped, so export the results promptly.

If execution leaves a failed transaction open, run `ROLLBACK;` before retrying the corrected script. Expected temporary-schema notices are not errors. The corrected capture script converts decimal-formatted `Actual Rows` through `NUMERIC` before `BIGINT`.

**If optimisation has already succeeded:** do not rerun its index-creation statements or describe a new capture as the original baseline. Keep the existing exports. A fresh reproduction requires a separate database or branch restored to the pre-optimisation state. Q2 uses a relative date window, so comparisons across different Lagos dates require identical fixed date bounds or a fresh matched baseline before indexing.

## Optimisation Changes

| Target | Change | Reason |
|---|---|---|
| Q2 | Partial index `p2_appointments_scheduled_doctor_time_idx` on `(doctor_id, start_time, appointment_id)`, including patient and end-time fields | Supports doctor/time filtering for scheduled appointments |
| Q3 | Partial index `p2_laboratory_pending_queue_idx` on `(requested_at, request_id)`, including appointment ID | Supports oldest-first access to pending requests |
| Q3 | Partial index `p2_laboratory_pending_items_idx` on `(request_id, request_item_id)`, including test ID | Supports pending test-item retrieval for each request |
| Q3 | Materialised CTE that selects the first 50 queue items before descriptive joins | Reduces appointment and patient lookups |
| Q1/Q4 | No query-specific changes | Q1 was already efficient; Q4 summarises the entire appointment table |

Existing Portfolio 1 indexes and exclusion constraints remain in place. New indexes consume storage and add maintenance work when relevant records or statuses change.

## Measured Results

The table uses the arithmetic mean of **runs 2 and 3**, excluding the first run from the primary comparison. Times are PostgreSQL **Execution Time**, in milliseconds; they exclude planning and browser/network response time.

| Query | Baseline mean (ms) | Optimised mean (ms) | Interpretation |
|---|---:|---:|---|
| Q1 | 0.1050 | 0.1125 | Essentially unchanged; 0.0075 ms increase |
| Q2 | 0.8875 | 0.6580 | 25.86% lower execution time |
| Q3 | 6.6880 | 0.3205 | 95.21% lower execution time; approximately 20.87× faster |
| Q4 | 16.1205 | 16.0285 | Essentially unchanged; 0.57% difference |

Percentage reduction is calculated as `(baseline − optimised) / baseline × 100`.

### Execution-Plan Findings

- **Q1:** Continues using the existing patient, appointment, doctor, and diagnosis indexes. The plan is unchanged.
- **Q2:** Uses the new scheduled-appointment B-tree index instead of the GiST exclusion index. A bitmap scan and final sort remain; the new index did not eliminate sorting in the captured plan.
- **Q3:** The baseline joins 1,500 matching rows before limiting to 50. The revised plan uses both pending-work indexes and processes 51 queue rows before producing the 50-row queue, followed by 50 appointment and patient lookups. Root shared-hit blocks rise from 333 to 460 in run 3, so the improvement must not be attributed to fewer total buffer hits.
- **Q4:** Retains a sequential scan over 30,001 appointments and aggregation into eight months. A full scan is reasonable for this whole-table summary.

Full run-by-run timings and interpretation are in the linked performance analysis.

## Correctness Verification

All captured row counts match between baseline and optimised runs: **6, 250, 50, and 8**.

Before capturing the optimised plans, the script compares the complete original and rewritten Q3 results using bidirectional `EXCEPT ALL`, preserving duplicate multiplicity. The export records **`PASS: Q3 equivalent before capture`**. That message refers specifically to Q3, even though it appears on every exported row.

Q1, Q2, and Q4 query text is unchanged. Matching counts alone do not prove full-row equality across separate captures. Ordinary query-result exports or screenshots remain a separate assessment requirement; the plan exports do not replace them.

## Limitations and Reflection

The clearest improvement came from reducing intermediate work in Q3 rather than adding indexes indiscriminately. Q4 demonstrates that a sequential scan can be appropriate, and Q1 shows that an already selective query may need no additional index.

These measurements are a small educational sample. Several initial runs read uncached blocks, and index creation, statistics refreshes, and the Q3 equivalence check can warm caches. Only two repeated timings per query are averaged. Neon compute configuration and competing workload were not recorded in the exports, so the results are observations rather than statistically established production guarantees.

Q3's indexes and rewrite were applied together; their individual contributions were not isolated. Index storage and write overhead were not measured. Record available Neon compute settings and capture context when finalising the submission, and adapt this reflection to your own understanding and experience.

## AI Assistance

ChatGPT assisted with SQL drafting, plan interpretation, and documentation. The submitted plan exports provide execution evidence from Neon. The student remains responsible for reviewing the scripts, checking results, acknowledging assistance, and explaining the implementation and conclusions.

## Final Checklist

- [ ] All linked scripts and the performance analysis are uploaded.
- [ ] Original baseline and optimised JSON exports are uploaded unchanged.
- [ ] Ordinary results for Q1–Q4 are saved under `evidence/query-results/`.
- [ ] Relative links work and the assessor can access the private repository.
- [ ] Measured findings, limitations, and individual reflection have been reviewed.
