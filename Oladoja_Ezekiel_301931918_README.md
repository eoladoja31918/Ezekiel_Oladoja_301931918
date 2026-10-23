# MIT 8103 Advanced Database Systems Portfolio

**Student:** Ezekiel Oladoja | 301931918  
**Academic session:** 2026/2027 — First Semester  
**Case study:** Hospital / Clinic Management System  
**Assessment:** Individual Practical Database Portfolio

## Project Overview

This portfolio applies database design, query optimisation, transaction management, NoSQL modelling, and cloud database concepts to a simulated clinic. The clinic registers patients, schedules consultations, records diagnoses and prescriptions, requests laboratory tests, and retrieves clinical history.

PostgreSQL on Neon supports the relational implementation. MongoDB Atlas demonstrates laboratory reports as documents with embedded measurements. The two databases are separate educational implementations: MongoDB appointment and requested-test references are explicitly simulated, and no cross-database synchronisation is implemented.

All records are fictional. The project is not a production clinical system.

## Portfolio Navigation and Assessment Mapping

| Component | Focus and deliverables ||
|---|---|---:|
| [Portfolio 1](portfolio-1-database-design/README.md) | Case study, business rules, ER diagram, relational schema, keys, constraints, and normalisation |  
| [Portfolio 2](portfolio-2-query-optimisation/README.md) | SQL queries, ordinary results, execution plans, targeted optimisation, and performance analysis |  
| [Portfolio 3](portfolio-3-transactions-concurrency/README.md) | COMMIT, ROLLBACK, READ COMMITTED isolation, competing bookings, and evidence review |  
| [Portfolio 4](portfolio-4-nosql/README.md) | MongoDB document model, validation, indexes, sample reports, queries, updates, and suitability |  
| [Portfolio 5](portfolio-5-distributed-cloud/README.md) | Cloud deployment inspection, replication, consistency, availability discussion, and sharding proposal |  
| Final documentation | 2–3 page summary, repository link, individual reflection, references, and AI-use declaration |  



## Repository Structure

```text
Oladoja_Ezekiel_301931918_/
├── Oladoja_Ezekiel_301931918_README.md
├── portfolio-1-database-design/
│   ├── Oladoja_Ezekiel_301931918_README.md
│   ├── Oladoja_Ezekiel_301931918_case-study.md
│   ├── Oladoja_Ezekiel_301931918_entities.md
│   ├── Oladoja_Ezekiel_301931918_business-rules.md
│   ├── Oladoja_Ezekiel_301931918_normalisation.md
│   ├── Oladoja_Ezekiel_301931918_er-diagram.png
│   ├── sql/
│   │   ├── Oladoja_Ezekiel_301931918_schema.sql
│   │   ├── Oladoja_Ezekiel_301931918_seed.sql
│   │   └── Oladoja_Ezekiel_301931918_validation.sql
│   └── evidence/
├── portfolio-2-query-optimisation/
│   ├── Oladoja_Ezekiel_301931918_README.md
│   ├── sql/
│   │   ├── Oladoja_Ezekiel_301931918_generate-data.sql
│   │   ├── Oladoja_Ezekiel_301931918_queries.sql
│   │   ├── Oladoja_Ezekiel_301931918_capture-baselines.sql
│   │   └── Oladoja_Ezekiel_301931918_optimisation.sql
│   ├── analysis/Oladoja_Ezekiel_301931918_performance-comparison.md
│   └── evidence/
│       ├── Oladoja_Ezekiel_301931918_query-results/
│       ├── baseline-plans/Oladoja_Ezekiel_301931918_baseline-plans.json
│       └── optimised-plans/Oladoja_Ezekiel_301931918_optimised-baseline-plans.json
├── portfolio-3-transactions-concurrency/
│   ├── Oladoja_Ezekiel_301931918_README.md
│   ├── sql/
│   │   ├── Oladoja_Ezekiel_301931918_01-setup.sql
│   │   ├── Oladoja_Ezekiel_301931918_02-commit-rollback.sql
│   │   ├── Oladoja_Ezekiel_301931918_03-isolation-session-a.sql
│   │   ├── Oladoja_Ezekiel_301931918_04-isolation-session-b.sql
│   │   ├── Oladoja_Ezekiel_301931918_05-booking-session-a.sql
│   │   ├── Oladoja_Ezekiel_301931918_06-booking-session-b.sql
│   │   └── Oladoja_Ezekiel_301931918_07-verify.sql
│   └── evidence/
├── portfolio-4-nosql/
│   ├── Oladoja_Ezekiel_301931918_README.md
│   ├── Oladoja_Ezekiel_301931918_model-design.md
│   ├── scripts/
│   │   ├── Oladoja_Ezekiel_301931918_01-setup.js
│   │   ├── Oladoja_Ezekiel_301931918_02-seed.js
│   │   └── Oladoja_Ezekiel_301931918_03-queries.js
│   └── evidence/
├── portfolio-5-distributed-cloud/
│   ├── Oladoja_Ezekiel_301931918_README.md
│   ├── Oladoja_Ezekiel_301931918_architecture.md
│   ├── scripts/Oladoja_Ezekiel_301931918_01-inspect-deployment.js
│   └── evidence/Oladoja_Ezekiel_301931918_deployment-inspection.json
└── documentation/
    └── Ezekiel_Oladoja_301931918_Final_Portfolio_Summary.pdf
```

This is the repository layout. The final summary has been uploaded to the linked location below; optional additional evidence and reference files have also been included.

## Technologies and Prerequisites

| Technology | Use |
|---|---|
| PostgreSQL 14 or later | Relational schema, SQL, integrity, transactions, and execution plans |
| Neon SQL Editor | Standalone SQL execution and result capture |
| `btree_gist` extension | Appointment overlap exclusion constraints |
| Two persistent PostgreSQL connections | Correctly interleaved isolation and concurrency exercises |
| MongoDB Atlas and mongosh | Document implementation and read-only deployment inspection |
| GitHub private repository | Scripts, documentation, evidence, and progressive commits |


## Relational and Document Models

The PostgreSQL `clinic` schema contains ten tables: `patients`, `doctors`, `appointments`, `diagnoses`, `prescriptions`, `prescription_items`, `laboratory_requests`, `laboratory_tests`, `laboratory_request_items`, and `laboratory_results`.

The design separates repeating items and entity facts through 1NF, 2NF, and 3NF. Primary keys, unique business identifiers, foreign keys, required fields, status checks, scheduling exclusion constraints, and deferred minimum-item checks support integrity.

MongoDB `clinic_nosql.laboratory_reports` contains one document per requested test, with embedded test details and measurement objects. Strict validation supports numeric and qualitative results. Unique report and request-item indexes protect business identifiers, while a compound patient-history index supports retrieval by patient and date.

## Execution Guide

Read each portfolio README before running its scripts. Use the same PostgreSQL database throughout Portfolios 1–3 and the same Atlas deployment throughout Portfolios 4–5.

### PostgreSQL Sequence

1. **Portfolio 1:** Run `schema.sql`, then `seed.sql`, then `validation.sql`. Confirm the ten tables and capture actual constraint-test results.
2. **Portfolio 2:** Run `generate-data.sql` once. Run the four queries normally and retain result evidence. Run `capture-baselines.sql`, export the 12-row baseline grid, and preserve it unchanged. Then run `optimisation.sql` once and export its 12-row grid.
3. **Portfolio 3:** Run `01-setup.sql` and `02-commit-rollback.sql` once. Follow the isolation and booking scripts section by section, interleaving two independent persistent sessions. Run `07-verify.sql` after resolving both transactions.

Do not rerun successful schema creation, seed batches, index creation, or committed test bookings blindly. Existing identifiers and overlapping appointments are intentionally rejected. After a failed transaction, run `ROLLBACK;` in that connection and inspect the error before retrying. Rolled-back identity values can leave normal gaps.

For a fresh optimisation reproduction after indexes already exist, use a separate database or branch restored to the pre-optimisation state. A new plan captured after indexing is not the original baseline. Keep date bounds and compute settings comparable.

### MongoDB Sequence

Connect mongosh to Atlas using your database user, then load each file separately using its actual local path:

```javascript
load("C:/path/to/portfolio-4-nosql/scripts/01-setup.js")
load("C:/path/to/portfolio-4-nosql/scripts/02-seed.js")
load("C:/path/to/portfolio-4-nosql/scripts/03-queries.js")
load("C:/path/to/portfolio-5-distributed-cloud/scripts/01-inspect-deployment.js")
```

Setup and seed stop on existing collection/batch identifiers rather than overwrite data. Ordered multi-document insertion is not atomic across all documents; inspect partial results after errors. The query script completes only pending `P4-LAB-0002` and skips an already-completed report on reruns.

The inspection script is read-only. Save its final Extended JSON block as `portfolio-5-distributed-cloud/evidence/deployment-inspection.json` without the surrounding print labels. It does not trigger failover, change settings, or enable sharding.

## Verified Results

### Query Optimisation

Actual Neon exports contain three runs per query before and after optimisation. The comparison uses the mean of runs 2 and 3 to reduce first-run cache effects. Times are PostgreSQL EXPLAIN **Execution Time**, not browser or network response time.

| Query | Baseline mean ms | Optimised mean ms | Finding |
|---|---:|---:|---|
| Patient history | 0.1050 | 0.1125 | Essentially unchanged |
| Doctor schedule | 0.8875 | 0.6580 | 25.86% reduction |
| Pending laboratory queue | 6.6880 | 0.3205 | 95.21% reduction |
| Monthly appointment summary | 16.1205 | 16.0285 | Essentially unchanged |

Q3's complete result-equivalence check passed. Its revised plan limits the queue before descriptive joins and uses the new pending-work indexes. All four queries retain their captured row counts. Q4's full-table summary appropriately retains a sequential scan. These small-sample results do not establish general production guarantees or isolate Q3's index and rewrite contributions.

### Transactions and Evidence Limits

Verification shows **one persisted booking/note** and **zero records for the rolled-back booking slot**. Final booking evidence shows appointment **30015**, patient **P3-P-01**, doctor **P3-D-01**, on **1 February 2035, 09:00–09:30 WAT**, status `scheduled`.

The supplied screenshots do not establish the complete rollback sequence, before/after isolation values, or simultaneous waiting. Both booking captures show PID **753**. Different isolation-script PIDs captured at different times do not prove concurrent interleaving. Portfolio 3 documents these limits and the required evidence.

### MongoDB and Cloud Inspection

- Strict collection validation and four indexes are observed.
- Deployment inspection confirms **five reports: three completed, one pending, one in-progress**.
- `P4-LAB-0002` is observed completed in the later inspection; its initial update acknowledgement is not visible in the supplied query screenshot.
- Replica set **`atlas-2t8ax2-shard-0`** reports **one PRIMARY and two SECONDARY**, all with `health: 1` at inspection.
- An explicit majority read was acknowledged.
- Default-concern inspection returned **code 59, CommandNotFound**; its precise restriction cause is not established.


## Evidence and Submission

Genuine screenshots, JSON exports, and measured outputs have been uploaded into their portfolio evidence folders. SQL or JavaScript comments describe expected outcomes are not execution evidence. 

The LMS deliverable is the [three-page final portfolio summary]([Ezekiel_Oladoja_301931918_Final_Portfolio_Summary](https://github.com/eoladoja31918/Oladoja_Ezekiel_301931918/blob/main/Ezekiel_Oladoja_301931918_Final_Portfolio_Summary.pdf). The repository URL, review the reflection and identified evidence gaps are acessible to the assessor, and  the assessor can access the private repository. Assessors can use the links in this README to navigate all five activities.

## Limitations

This model does not implement production clinical approvals, comprehensive audit history, consent management, role-based application access, or tested backup/recovery. No live PostgreSQL–MongoDB consistency mechanism exists. The five-document sample does not justify sharding. Proposed sharding cannot retain the current separate global unique indexes unchanged.


## Individual Reflection and AI Assistance

Each portfolio README records technical interpretation and limitations. The final summary contains a reflection covering design choices, query-plan analysis, execution errors, session management, and cloud evidence. 

ChatGPT assisted with planning, script drafting, evidence analysis, and documentation. Verification used actual Neon exports, MongoDB outputs, and screenshots; unsupported outcomes are not claimed as successful. 

## References

- MIT 8103 First Semester Continuous Assessment brief, September Cohort 2026, 2026/2027 session.
- [PostgreSQL documentation](https://www.postgresql.org/docs/) — constraints, transactions, isolation, indexes, and EXPLAIN.
- [MongoDB manual](https://www.mongodb.com/docs/manual/) — validation, document operations, replication, concerns, and sharding.
- [MongoDB Atlas documentation](https://www.mongodb.com/docs/atlas/) — deployment, connection, and command limitations.
