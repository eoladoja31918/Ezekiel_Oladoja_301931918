# Portfolio 4: NoSQL and Advanced Data Models

**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** Hospital / Clinic Management System  
**Platform:** MongoDB Atlas, accessed through mongosh  
**Database / collection:** `clinic_nosql.laboratory_reports`

## Objective and Assessment Mapping

Implement a document model for laboratory reports using the same clinic case study as the relational portfolios. Each document represents one requested test and embeds its measurements.

| Assessment requirement | Implementation and evidence |
|---|---|
| NoSQL model based on the same case study | Clinic report model referencing patients, appointments, and requested tests |
| Document/key-value/column/graph example | MongoDB document example with nested test details and measurement arrays |
| Implementation evidence | Setup, seed, and query scripts with three actual execution screenshots |
| Explanation of suitability | Embedding, references, flexible measurements, integrity, and trade-offs below |

This portfolio implements one document model, not all four NoSQL categories.

## Files

| File | Purpose |
|---|---|
| [model-design.md](model-design.md) | Document structure, field types, rules, indexes, and design justification |
| [01-setup.js](scripts/01-setup.js) | Creates the collection, validator, and application indexes |
| [02-seed.js](scripts/02-seed.js) | Inserts five fictional laboratory reports |
| [03-queries.js](scripts/03-queries.js) | Retrieves reports, searches measurements, completes one report, and explains a query |
| [01-setup.png](evidence/01-setup.png) | Actual setup configuration and indexes |
| [02-seed.png](evidence/02-seed.png) | Actual stored sample documents |
| [03-queries.png](evidence/03-queries.png) | Actual explain output and query-script completion |

Upload screenshots under their exact linked names. The JavaScript files must be extracted from their download ZIPs before committing them to `scripts/`.

## Model Summary

A report contains:

- MongoDB `_id`, unique `report_number`, and `schema_version`.
- `patient_number`, plus string-valued appointment and requested-test references.
- Embedded `test` code and name as a historical snapshot.
- Status, request date, optional reporting date, and comments.
- Embedded `measurements`, each with code, name, numeric or qualitative value, and optional unit.

Completed reports require a reporting date and at least one measurement. Dates must be ordered correctly, and measurement codes must be distinct within each report. Pending reports can have empty measurements and omit `reported_at`.

The sample appointment IDs `901001`–`901005` and requested-test IDs `902001`–`902005` are explicitly **simulated**. Their existence and relationships in PostgreSQL were not checked. Reusing patient business identifiers connects the scenario conceptually; it does not establish live database integration.

## Running the Scripts

1. Connect mongosh to the Atlas cluster using your database user. Ensure the current IP is allowed and the user can work with `clinic_nosql`.
2. Confirm connectivity with `db.runCommand({ ping: 1 })`.
3. Load each complete file in order, adjusting the Windows path:

```javascript
load("C:/Users/Ezekiel Oladoja/Downloads/clinic-mongodb-setup/01-setup.js")
load("C:/Users/Ezekiel Oladoja/Downloads/clinic-mongodb-seed/02-seed.js")
load("C:/Users/Ezekiel Oladoja/Downloads/clinic-mongodb-queries/03-queries.js")
```

Run each `load` separately and inspect its output before continuing. All scripts explicitly select `clinic_nosql` through `db.getSiblingDB`; the shell prompt may still display `test`. This does not mean data was written to the wrong database.

Setup stops if the collection exists. Seed stops if any batch report numbers or requested-test references already exist. Do not delete earlier work merely to rerun these scripts. Collection/index creation is not a single transaction, and ordered `insertMany` is not atomic across all documents: inspect existing state after a failure.

The query script updates only pending `P4-LAB-0002`. On a later run it skips an already-completed report, so that rerun is not new evidence of the original transition. No script deletes reports.

## Operations Demonstrated by the Scripts

| Operation | Script action |
|---|---|
| Patient history | Find `PAT001` reports, newest request first |
| Pending queue | Retrieve pending reports in the known P4 seed batch |
| Nested test filter | Find completed reports with `test.code = FBC` |
| Numeric measurement search | `$elemMatch` for `HB` with a value greater than 13 |
| Qualitative measurement search | `$elemMatch` for a `FINDING` value of `not detected` |
| Completion update | Set measurements, status, and reporting date together for `P4-LAB-0002` |
| Verification | Read the updated report, pending queue, and grouped status counts |
| Explain | Inspect execution statistics for the indexed patient-history query |

The numeric threshold is an arbitrary query example, not clinical advice. `$elemMatch` ensures the code and value conditions concern the same measurement object.

## Extracted Implementation Evidence

The following describes only what is visible in the supplied screenshots. Output printed above the captured area is not treated as directly inspected evidence.

### 1. Collection Setup — Confirmed

[01-setup.png](evidence/01-setup.png) shows:

- `validationLevel: 'strict'` and `validationAction: 'error'`.
- The validator tail includes measurement-code uniqueness logic using `$size` and `$setUnion`.
- Default index `_id_` on `{ _id: 1 }`.
- Unique `uq_report_number` on `{ report_number: 1 }`.
- Unique `uq_request_item_id` on `{ request_item_id: 1 }`.
- `ix_patient_report_history` on `{ patient_number: 1, requested_at: -1, report_number: 1 }`.
- Initial document count `0` and return to the shell prompt without a visible error.

This verifies stored setup configuration. It does not demonstrate an attempted invalid insert being rejected.

### 2. Seed Documents — Confirmed Examples

[02-seed.png](evidence/02-seed.png) visibly contains these stored documents:

| Report | Patient | Test | Status | Visible result |
|---|---|---|---|---|
| `P4-LAB-0003` | `P2-P-00002` | `QUAL` / Demo Qualitative Test | completed | `FINDING: not detected`; requested 19 October 2026 09:00 UTC, reported 11:00 UTC |
| `P4-LAB-0004` | `P2-P-00002` | `RENAL` / Demo Kidney Panel | in-progress | Empty measurements; requested 20 October 2026 10:00 UTC |
| `P4-LAB-0005` | `P2-P-00003` | `LIVER` / Demo Liver Panel | pending | Empty measurements; requested 20 October 2026 11:00 UTC |

The screenshot also contains the tail of the pending-report example and ends with the script's warning that no PostgreSQL reference checks were performed. It returns to the prompt without a visible error.

The seed script specifies five reports with initial counts of **2 completed, 2 pending, and 1 in-progress**, and verifies those counts before printing its documents. The screenshot is consistent with completion, but the insertion acknowledgement, full first two documents, and summary are outside its visible area.

### 3. Queries and Explain — Confirmed Visible Output

[03-queries.png](evidence/03-queries.png) shows:

- Explain command `find: 'laboratory_reports'`, with `$db: 'clinic_nosql'`.
- Filter `{ patient_number: 'PAT001' }`.
- Sort `{ requested_at: -1, report_number: 1 }`.
- Index bounds for `patient_number`, `requested_at`, and `report_number`.
- `keysExamined: 2`, `seeks: 1`, `dupsTested: 0`, and `dupsDropped: 0` in the visible index execution detail.
- MongoDB server version `8.0.34` and explain acknowledgement `ok: 1`.
- `QUERIES FINISHED` and return to the shell prompt without a visible error.

The visible index detail supports index-backed access for the patient-history lookup. It does not establish a performance improvement: no before/after benchmark or complete top-level timing comparison was supplied.

Because this script prints its completion message only after its update and stored-state checks, reaching that message supports that the script completed those checks. However, the screenshot does not show whether the update occurred on that run or was skipped as already completed. It does not directly display `matchedCount`, `modifiedCount`, before/after documents, or final status totals.

### Verification Status

| Item | Status |
|---|---|
| Strict/error validator and four indexes | Confirmed in setup screenshot |
| Qualitative, in-progress, and pending document examples | Confirmed in seed screenshot |
| Script reaching the end of queries/explain | Confirmed in query screenshot |
| Patient-history indexed execution detail | Confirmed; two keys examined |
| Actual update acknowledgement and before/after state | Additional visible output needed |
| Final status totals: 3 completed, 1 pending, 1 in-progress | Expected after initial completion; summary not visible in screenshot |
| Duplicate-key/invalid-document rejection attempts | Not executed or evidenced in supplied screenshots |

## Supplementary Result Capture

Run the following read-only checks in mongosh to capture the current report state and final batch counts without repeating setup or seed:

```javascript
const p4db = db.getSiblingDB("clinic_nosql");

p4db.laboratory_reports.find(
  { report_number: "P4-LAB-0002" },
  { _id: 0, report_number: 1, status: 1, measurements: 1, reported_at: 1 }
).toArray();

p4db.laboratory_reports.aggregate([
  { $match: { report_number: { $in: [
    "P4-LAB-0001", "P4-LAB-0002", "P4-LAB-0003", "P4-LAB-0004", "P4-LAB-0005"
  ] } } },
  { $group: { _id: "$status", count: { $sum: 1 } } },
  { $sort: { _id: 1 } }
]).toArray();
```

Save additional output under `evidence/` and update this section. Recover the original update acknowledgement from terminal scrollback if available; rerunning an already-completed report cannot recreate evidence of its first update.

## Why This Model Is Suitable

Laboratory reports have a common header but varying numbers and types of measurements. A validated document structure permits numeric and qualitative results without adding new columns for every test. Embedded measurements belong to the report and can be retrieved together. A single-document completion update changes report fields atomically.

Patient and appointment references avoid duplicating personal details, while the embedded test name deliberately preserves a historical snapshot. The patient-history index supports the expected lookup pattern.

| Aspect | PostgreSQL model | MongoDB report model |
|---|---|---|
| Measurements | Separate relational rows | Embedded array elements |
| Report retrieval | Joins across relevant tables | Self-contained report document |
| Relationship integrity | Foreign keys within PostgreSQL | External references checked outside MongoDB |
| Test description | Catalogue reference | Embedded snapshot |
| Main trade-off | More relational joins | Snapshot duplication and reference coordination |

## Limitations and Learning

No cross-database synchronisation, clinical approval, or report-revision history is implemented. The sample is too small to establish general performance claims. Unique indexes enforce document identifiers but do not verify simulated PostgreSQL references. Configuration evidence is distinct from demonstrating rejection of invalid writes.

A key design lesson is to embed information that shares a bounded report lifecycle, while keeping separate clinic entities referenced. A key evidence lesson is to save labelled query results and update acknowledgements, not only the final screen of a long script.

## AI Assistance and Final Checklist

ChatGPT assisted with model design, scripts, and evidence interpretation. The student remains responsible for understanding, executing, reviewing, and explaining the work and declaring assistance in the final submission.

