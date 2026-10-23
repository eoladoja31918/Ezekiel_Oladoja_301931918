Portfolio 2: Query Performance Comparison
Evidence and Method
This analysis uses the actual Neon exports baseline-plans.json and optimised-baseline-plans.json. Each contains four queries executed three times, including complete JSON execution plans. Preserve both original exports in the evidence folders.
The primary comparison is the arithmetic mean of runs 2 and 3. The first run is reported separately because several first-run plans read blocks not already in PostgreSQL shared buffers. Repeated runs in these exports show zero shared read blocks at the plan roots; this supports a warm-cache comparison but does not prove identical operating conditions.
Times below are PostgreSQL EXPLAIN ANALYZE Execution Time, in milliseconds. They exclude Planning Time and are not browser response times.
Repeated-Run Comparison
Positive reduction means faster; negative means slower.
Query	Baseline mean (ms)	Optimised mean (ms)	Execution-time reduction	Returned rows
Q1 Patient history	0.1050	0.1125	-7.14%	6
Q2 Doctor schedule	0.8875	0.6580	+25.86%	250
Q3 Pending laboratory tests	6.6880	0.3205	+95.21%	50
Q4 Monthly summary	16.1205	16.0285	+0.57%	8


Reduction = (baseline mean − optimised mean) / baseline mean × 100.
Individual Execution Times
Query	Baseline runs 1 / 2 / 3 (ms)	Optimised runs 1 / 2 / 3 (ms)
Q1	0.116 / 0.105 / 0.105	8.245 / 0.108 / 0.117
Q2	111.52 / 0.913 / 0.862	33.169 / 0.66 / 0.656
Q3	201.601 / 6.708 / 6.668	0.343 / 0.33 / 0.311
Q4	35.655 / 16.15 / 16.091	16.543 / 16.001 / 16.056


Findings
Q1: Patient History
The query returns six appointments and uses the existing patient-number, appointment-patient, doctor-primary-key, and diagnosis-appointment indexes. Its repeated-run mean changes from 0.1050 ms to 0.1125 ms, an increase of 0.0075 ms. No Q1-specific change was introduced and the plan remains the same. This small difference is not evidence of a meaningful regression or improvement.
Q2: Doctor Schedule
The query returns 250 appointments. Its appointment lookup changes from the GiST exclusion index doctor_schedule_no_overlap to the new partial B-tree index p2_appointments_scheduled_doctor_time_idx.
The repeated-run mean falls from 0.8875 ms to 0.6580 ms, a 25.86% reduction. The final sort remains; the optimiser chose a bitmap scan rather than an ordered index scan. The root shared-hit count changes only slightly, from 807 to 806 in run 3. The observed benefit is modest and should be confirmed with more repetitions before drawing broad conclusions.
A sequential scan of the 21-row doctors table is reasonable and does not indicate a missing-index problem.
Q3: Pending Laboratory Queue
The query returns the oldest 50 pending test items. In the baseline plan, 1,500 matching rows are joined before a top-N sort and limit. The appointment index scan visits 14,995 rows, and a patient scan visits 5,001 rows.
The revised query materialises a limited queue before retrieving appointment, patient, and test descriptions. Its plan uses both p2_laboratory_pending_queue_idx and p2_laboratory_pending_items_idx. The queue-building nested loop produces 51 rows to supply the incremental sort and 50-row limit. Only 50 appointment and patient lookups are then required.
The repeated-run mean falls from 6.6880 ms to 0.3205 ms: a 95.21% execution-time reduction, or approximately 20.87 times faster in this sample. This is the strongest observed improvement, supported by reduced intermediate row processing.
Root shared-hit blocks actually rise from 333 to 460 in run 3. Therefore, the improvement must not be described as fewer total buffer hits. Indexed lookups and earlier limiting change the work performed, even though they produce more repeated buffer accesses.
Both indexes and the query rewrite were applied together. These measurements establish their combined effect; they do not isolate the contribution of each change.
Q4: Monthly Summary
The query returns eight monthly groups after scanning 30,001 appointments. Its sequential scan and aggregation remain unchanged. The repeated-run mean changes from 16.1205 ms to 16.0285 ms, a 0.57% reduction. This small difference is inconclusive and should not be claimed as an optimisation benefit.
The query summarises the entire appointment table. A full scan is an appropriate plan for this workload, so no additional Q4 index was introduced.
Correctness
All four queries retain the same returned row counts: Q1 = 6, Q2 = 250, Q3 = 50, and Q4 = 8.
The optimised export includes PASS: Q3 equivalent before capture. This confirms that the script's bidirectional EXCEPT ALL check found no differences between the complete original and rewritten Q3 result rows in the verification snapshot. The message repeated on Q1/Q2/Q4 rows refers only to that Q3 check; it is not a full-row equivalence test for those other queries.
Q1, Q2 and Q4 query text was unchanged. Matching counts alone would not establish complete result equality between separately captured exports. Q2 uses a date-relative window, so future comparisons must use the same date window or fixed equivalent bounds.
Trade-offs and Limits
- Three partial indexes consume storage and add maintenance work to relevant inserts, deletes, and status/key updates. Index sizes and write overhead have not been measured.
- Partial indexes target scheduled appointments and pending laboratory work, rather than every row.
- No Portfolio 1 index or exclusion constraint was removed.
- Only two repeated timings per query are averaged. This is a small sample, not a statistical significance test.
- Neon compute settings, caching, shared workload, and the equivalence check performed before optimised capture can affect timings. Hardware/compute configuration was not recorded in the exports.
- Index creation, ANALYZE, and preliminary queries can warm caches. First-run differences must not be attributed entirely to optimisation.
- Query-plan instrumentation adds overhead. Results describe this educational dataset, not guaranteed production performance.
Portfolio Evidence Checklist
- Keep the original baseline export unchanged under evidence/baseline-plans/.
- Keep the optimised export under evidence/optimised-plans/.
- Include sql/queries.sql, sql/capture-baselines.sql, and sql/optimisation.sql.
- Retain ordinary query-result screenshots/exports separately; execution plans are not a substitute for query results.
- Add this report under analysis/performance-comparison.md and link it from the Portfolio 2 README.
- Record your Neon compute settings and capture-date context in the README if available.
