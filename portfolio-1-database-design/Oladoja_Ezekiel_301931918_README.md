# Portfolio 1: Database Design and Modelling

**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** Hospital / Clinic Management System  
**Database:** PostgreSQL hosted on Neon

## Overview

This project models a simulated clinic providing consultations, diagnoses, prescriptions, and laboratory services. Receptionists, doctors, nurses, laboratory staff, and administrators use the system to register patients, book appointments, record diagnoses, issue prescriptions, request tests, and retrieve patient history.

All sample records are fictional. This portfolio focuses on database design and integrity; it does not include a clinical application interface.

## Assessment Deliverables

| Requirement | File |
|---|---|
| Case study description | [Oladoja_Ezekiel_301931918_case-study.md](Oladoja_Ezekiel_301931918_case-study.md) |
| Entities and attributes | [Oladoja_Ezekiel_301931918_entities.md](Oladoja_Ezekiel_301931918_entities.md) |
| Business rules | [Oladoja_Ezekiel_301931918_business-rules.md](Oladoja_Ezekiel_301931918_business-rules.md) |
| ER diagram | [Oladoja_Ezekiel_301931918_er-diagram.png](https://github.com/eoladoja31918/Oladoja_Ezekiel_301931918/blob/main/portfolio-1-database-design/Oladoja_Ezekiel_301931918_er-diagram.png) |
| Relational schema, keys, and constraints | [Oladoja_Ezekiel_301931918_schema.sql](sql/Oladoja_Ezekiel_301931918_schema.sql) |
| Normalisation explanation | [Oladoja_Ezekiel_301931918_normalisation.md](Oladoja_Ezekiel_301931918_normalisation.md) |
| Synthetic sample data | [Oladoja_Ezekiel_301931918_seed.sql](sql/Oladoja_Ezekiel_301931918_seed.sql) |
| Constraint validation | [Oladoja_Ezekiel_301931918_validation.sql](sql/Oladoja_Ezekiel_301931918_validation.sql) |
| Execution evidence | [evidence folder](evidence/) |

![Clinic entity relationship diagram](https://github.com/eoladoja31918/Oladoja_Ezekiel_301931918/blob/main/portfolio-1-database-design/Oladoja_Ezekiel_301931918_er-diagram.png)

## Database Structure

The `clinic` schema contains ten tables:

| Table | Purpose |
|---|---|
| `patients` | Patient identity and contact details |
| `doctors` | Doctor details and specialisation |
| `appointments` | Patient–doctor consultations and scheduling |
| `diagnoses` | Diagnoses associated with appointments |
| `prescriptions` | Prescription headers, issue times, and status |
| `prescription_items` | Individual medications and usage instructions |
| `laboratory_requests` | Laboratory request headers |
| `laboratory_tests` | Available test catalogue |
| `laboratory_request_items` | Tests included in each request |
| `laboratory_results` | Individual measurements and findings |

## Setup and Execution in Neon

1. Open a Neon PostgreSQL project and select the intended branch and database. The existing `neondb` database can be used.
2. Open **SQL Editor**. Use the same branch and database for every script.
3. Open each linked SQL file, copy its complete contents into the editor, and run it without selecting an isolated statement or fragment.
4. Execute the scripts in this order:

| Order | Script | Expected behaviour |
|---|---|---|
| 1 | `sql/schema.sql` | Creates the `clinic` schema, ten tables, indexes, functions, and triggers |
| 2 | `sql/seed.sql` | Inserts connected fictional records into all ten tables |
| 3 | `sql/validation.sql` | Reports 12 checks and rolls back its test records |

The schema targets PostgreSQL 14 or later and requires the `btree_gist` extension for appointment overlap constraints. If extension creation is denied, resolve the permissions or extension availability before continuing.

Run `schema.sql` and `seed.sql` once. Re-running them after successful execution will cause existing-object or unique-value conflicts. Do not delete the schema simply to rerun a script.

After schema creation, verify the table list:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'clinic'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

Expected result: ten table names.

After loading the seed data, inspect representative records:

```sql
SELECT * FROM clinic.patients;
SELECT * FROM clinic.doctors;
SELECT * FROM clinic.appointments;
SELECT * FROM clinic.laboratory_results;
```

The schema uses generated identifiers. The seed script captures these identifiers to link records without assuming fixed ID values. Explicit timestamp offsets identify sample event times; timestamps use `TIMESTAMPTZ`.

If a script stops in a failed transaction, execute the following before retrying the corrected script:

```sql
ROLLBACK;
```

## Validation and Evidence

**Actual validation status: awaiting confirmation.** The final Neon result grid has not been supplied for this documentation. The expected outcomes below must not be treated as observed results.

| Check | Expected outcome |
|---|---|
| Valid patient, doctor, and appointment | Accepted |
| Duplicate patient number | Rejected |
| Nonexistent patient reference | Rejected |
| Zero-duration appointment | Rejected |
| Doctor double booking | Rejected |
| Patient double booking | Rejected |
| Adjacent appointments without overlap | Accepted |
| Missing patient first name | Rejected |
| Invalid appointment status | Rejected |
| Future date of birth | Rejected |
| Finalised prescription without items | Rejected |
| Submitted laboratory request without tests | Rejected |

The script checks error codes and identifying messages for rejected operations. Expected failures are caught and reported as PASS when the intended constraint rejects the operation. Unexpected acceptance or a different error is reported as FAIL.

Minimum-item triggers are normally deferred until transaction end. The validation script switches them to immediate checking for its isolated rejection tests. It does not verify concurrent transaction behaviour.

All validation fixtures are rolled back. Identity sequences may still advance, producing normal gaps in generated IDs. If execution stops unexpectedly, run `ROLLBACK;`.

### Evidence to Save

Save actual screenshots or exports using the following suggested names. These links become usable after the files are uploaded:

- [Ten-table verification](evidence/01-tables-created.png)
- [Loaded sample records](evidence/02-sample-data.png)
- [Validation results](evidence/03-validation-results.png)

After execution, replace the pending status with the actual test date, PASS/FAIL counts, and any fixes. Capture additional screenshots if all 12 result rows do not fit in one image. Never report unexecuted tests as passed.

## Design Choices

- **Normalisation:** The design separates repeating items for 1NF, header and item facts for 2NF, and patient, doctor, and catalogue details for 3NF. The worked explanation is in `normalisation.md`.
- **Keys:** Generated primary keys identify rows. Unique patient numbers, doctor numbers, and test codes provide business identifiers.
- **Relationships:** Foreign keys connect clinical records to existing parents. Restricted updates and deletions protect referenced identifiers and records.
- **Scheduling:** Exclusion constraints prevent overlapping scheduled appointments for the same patient or doctor. Half-open time ranges allow one appointment to begin when another ends.
- **Prescription workflow:** Draft headers may have no items. Finalised prescriptions require an issue time and at least one medication item.
- **Laboratory workflow:** Draft requests may have no items. Pending, in-progress, and completed requests require at least one requested test.
- **History retrieval:** Patient history is assembled through joins rather than copied into a separate history table.
- **Consistency:** The ER diagram includes `prescriptions.status`; the business rules should include the laboratory request `draft` state used by the SQL implementation.

## Limitations

- This is an educational model, not a production clinical system. Access-control roles, audit trails, consent, backups, billing, and record versioning are outside this portfolio's implementation.
- One specialisation is recorded per doctor. Medication names and instructions are free text rather than references to a managed medication catalogue.
- Laboratory result values are text to support numeric and qualitative findings. Numeric analysis and standardised measurement definitions would require further modelling.
- Overlap prevention applies to appointments marked `scheduled`. The model does not enforce a full clinical workflow or automatically reconcile all parent and child status changes.
- The sample dataset is small. Large-scale performance and multi-session concurrency require separate exercises.
- Prescription and laboratory header/item writes support READ COMMITTED or SERIALIZABLE transactions. REPEATABLE READ is rejected by the implemented guards. Applications using concurrent transactions must handle deadlocks or serialization failures.

## AI Assistance Declaration

ChatGPT assisted with drafting the design documentation and generating SQL and validation scripts. The student remains responsible for reviewing the design, executing and checking the scripts in Neon, correcting issues, and explaining the submitted work. Record completed verification and any corrections in the evidence and reflection rather than assuming generated code is correct.

