# Portfolio 3: Transactions and Concurrency

**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** Hospital / Clinic Management System  
**Platform:** PostgreSQL hosted on Neon

## Objective

Demonstrate COMMIT, ROLLBACK, transaction isolation, and concurrency control using the clinic database developed in Portfolio 1. The exercises show how PostgreSQL handles related writes, visibility of uncommitted changes, and competing appointment bookings.

All demonstration records are fictional. Reserved identifiers are `P3-P-01`, `P3-P-02`, and `P3-D-01`. The 2035 appointments are test fixtures, not real bookings.

## Assessment Mapping

| Required evidence | Demonstration | Supporting files |
|---|---|---|
| COMMIT | Save an appointment and an associated synthetic note together | `Oladoja_Ezekiel_301931918_02-commit-rollback.sql` and result output |
| ROLLBACK | Insert a second appointment, then discard it | `Oladoja_Ezekiel_301931918_02-commit-rollback.sql` and before/after output |
| Isolation | Compare visibility before and after another session commits | `Oladoja_Ezekiel_301931918_03-isolation-session-a.sql`, `Oladoja_Ezekiel_301931918_04-isolation-session-b.sql` |
| Concurrency issue or control mechanism | Attempt overlapping bookings for one doctor in two sessions | `Oladoja_Ezekiel_301931918_05-booking-session-a.sql`, `Oladoja_Ezekiel_301931918_06-booking-session-b.sql` |
| Screenshots/output evidence | Verify transaction outcomes and the surviving booking | `evidence/` and `Oladoja_Ezekiel_301931918_07-verify.sql` |

## Repository Files

| File | Purpose |
|---|---|
| [Oladoja_Ezekiel_301931918_01-setup.sql](sql/Oladoja_Ezekiel_301931918_01-setup.sql) | Creates two test patients and one test doctor |
| [Oladoja_Ezekiel_301931918_02-commit-rollback.sql](sql/Oladoja_Ezekiel_301931918_02-commit-rollback.sql) | Demonstrates persistence and explicit rollback |
| [Oladoja_Ezekiel_301931918_03-isolation-session-a.sql](sql/Oladoja_Ezekiel_301931918_03-isolation-session-a.sql) | Updates the doctor's name in Session A |
| [Oladoja_Ezekiel_301931918_04-isolation-session-b.sql](sql/Oladoja_Ezekiel_301931918_04-isolation-session-b.sql) | Reads the name before and after A commits |
| [Oladoja_Ezekiel_301931918_05-booking-session-a.sql](sql/Oladoja_Ezekiel_301931918_05-booking-session-a.sql) | Creates the first, initially uncommitted booking |
| [Oladoja_Ezekiel_301931918_06-booking-session-b.sql](sql/Oladoja_Ezekiel_301931918_06-booking-session-b.sql) | Attempts a conflicting booking |
| [Oladoja_Ezekiel_301931918_07-verify.sql](sql/Oladoja_Ezekiel_301931918_07-verify.sql) | Displays the surviving booking |
| [Evidence folder](evidence/) | Actual screenshots, outputs, and session observations |

## Prerequisites

- The existing `clinic` schema from [Portfolio 1](../portfolio-1-database-design/Oladoja_Ezekiel_301931918_README.md), including its foreign keys and appointment exclusion constraints.
- Access to the same Neon branch and database throughout the exercise.
- Permission to insert demonstration records and update the fictional doctor's name.
- Two independent persistent PostgreSQL connections for isolation and concurrent booking, preferably two interactive psql terminals using the direct, non-pooled Neon endpoint.

Do not assume that two Neon SQL Editor tabs provide stable independent sessions across separate requests. Multi-session exercises require both transactions to remain open in their respective connections. Use Neon SQL Editor for the standalone setup, COMMIT/ROLLBACK, and verification scripts.

Keep credentials out of GitHub, screenshots, and submitted logs.

## 1. Create the Demonstration Records

Run `Oladoja_Ezekiel_301931918_01-setup.sql` once. Confirm that the following records exist:

| Identifier | Record |
|---|---|
| `P3-P-01` | First test patient |
| `P3-P-02` | Second test patient |
| `P3-D-01` | Test doctor, initially named `P3 Demo Doctor` |

The setup is transactional. If an identifier already exists, stop and inspect the existing record rather than deleting records or rerunning the setup blindly.

## 2. Demonstrate COMMIT and ROLLBACK

Run `Oladoja_Ezekiel_301931918_02-commit-rollback.sql` once after successful setup.

### COMMIT

The first transaction inserts an appointment for `P3-P-01` with `P3-D-01` on **10 January 2035, 09:00–09:30 WAT**, and an associated synthetic note in `diagnoses`. COMMIT saves both changes.

The note illustrates related writes; recording it against a scheduled future appointment is a simplified test scenario, not a proposed clinical workflow.

### ROLLBACK

The second transaction inserts a **09:30–10:00 WAT** appointment on the same day. A query inside that transaction can see the new row. ROLLBACK then discards it.

### Expected Final Verification

| Check | Expected count |
|---|---:|
| Committed booking and synthetic note | 1 |
| Rolled-back booking | 0 |

Capture both the intermediate uncommitted row and final verification where possible. If Part A already committed during a previous run, repeating it causes an overlap error; inspect the existing records and run verification instead.

## 3. Demonstrate READ COMMITTED Isolation

Use the two isolation scripts. Execute their numbered sections separately in the order below; do not run either file uninterrupted.

First run this in both connections:

```sql
SELECT pg_backend_pid();
```

The PIDs must differ, and each connection must remain open throughout its exercise.

| Step | Session | Action | Expected observation |
|---|---|---|---|
| 1 | A | Begin READ COMMITTED; update the test doctor's name without committing | A sees `P3 Doctor - committed change` |
| 2 | B | Begin READ COMMITTED; read the same doctor | B still sees `P3 Demo Doctor` |
| 3 | A | COMMIT | The update becomes committed |
| 4 | B | Read again within B's existing transaction | B sees `P3 Doctor - committed change` |
| 5 | B | COMMIT | B's transaction ends |

This demonstrates two behaviours:

- **No dirty read:** B does not see A's uncommitted update.
- **Nonrepeatable read permitted:** B can see a different committed value on its next statement, because READ COMMITTED takes a new snapshot per statement.

If the doctor's name already has the updated value before the exercise, the before/after comparison cannot demonstrate the intended change. Inspect and deliberately reset only the fictional fixture before repeating the sequence. If B sees the new name on its first read, A may already have committed; do not claim dirty-read prevention from that observation alone.

## 4. Demonstrate Concurrent Appointment Booking

Use the booking scripts with two independent persistent sessions. Different patients are used so the conflict specifically concerns the same doctor.

| Session | Patient | Doctor | Appointment on 1 February 2035 |
|---|---|---|---|
| A | `P3-P-01` | `P3-D-01` | 09:00–09:30 WAT |
| B | `P3-P-02` | `P3-D-01` | 09:15–09:45 WAT |

### Required Execution Order

1. In A, begin the transaction and insert the first booking. Leave it uncommitted.
2. In B, begin its transaction and attempt the competing insert. B should wait for A's transaction to resolve.
3. While B is waiting, switch to A and COMMIT.
4. Observe B's exclusion-constraint error, normally SQLSTATE `23P01`, naming `doctor_schedule_no_overlap`.
5. Run `ROLLBACK;` in B to clear its failed transaction.
6. Run `Oladoja_Ezekiel_301931918_07-verify.sql` after both transactions have ended.

**Expected final result:** exactly one booking for `P3-P-01`, **09:00–09:30 WAT**, with status `scheduled`.

The GiST exclusion constraint prevents overlapping scheduled appointments for the same doctor. The separate patient exclusion constraint protects against patient double booking. These database controls prevent both sessions from committing conflicting bookings, even if an application-level availability check were passed by both users.

B has a two-minute lock timeout. A timeout is not the expected exclusion result: it means the wait was not resolved in time. An immediate exclusion error after A has already committed proves overlap prevention, but does not establish that concurrent waiting occurred.

## 5. ACID Interpretation

| Property | Application in this portfolio |
|---|---|
| Atomicity | A transaction saves related writes together or discards them through rollback |
| Consistency | Foreign keys, value checks, and exclusion constraints preserve defined rules |
| Isolation | READ COMMITTED hides uncommitted changes; conflicting bookings are coordinated through locking and constraints |
| Durability | Committed records remain visible in subsequent queries |

The exercises do not test crash recovery, backup restoration, or every isolation level. They also do not demonstrate that READ COMMITTED prevents all concurrency anomalies.

## Actual Results: Extracted Screenshot Evidence

Eight screenshots were reviewed, including the supplementary COMMIT/ROLLBACK verification. Their visible results are extracted below. Statement-status tabs, result grids, and script comments are distinguished: a comment describing an expected outcome is not proof that the outcome occurred.

Upload the supplied screenshots unchanged to `evidence/` using their original filenames so these links resolve.

| Screenshot | Visible extraction | What it establishes / limitation |
|---|---|---|
| [setup.png](evidence/setup.png) | Tabs show `1: BEGIN` and `2: ERROR`; banner says `Failed transaction: ROLLBACK required`. The selected BEGIN tab says `Statement executed successfully`. | This captured setup attempt stopped with an error. BEGIN success does not establish successful inserts or COMMIT. The error detail is not selected, so its cause cannot be extracted. |
| [commit-rollback.png](evidence/commit-rollback.png) | Tabs show `1: BEGIN` and `2: ERROR`, with `Failed transaction: ROLLBACK required`. The editor contains the rollback and final verification SQL, but no verification result grid is visible. | Does not confirm the expected counts of 1 committed booking/note and 0 rolled-back bookings. Visible SQL and comments are intended checks, not observed counts. |
| [isolation-session-a.png](evidence/isolation-session-a.png) | `session_a_pid = 823`. Tabs show `SELECT 1`, `BEGIN`, `UPDATE 1`, `SELECT 1`, `COMMIT`. The script sets READ COMMITTED and changes the doctor name to `P3 Doctor - committed change`. | Confirms one row was updated and the run reached COMMIT. The selected result is the PID, not the name; the updated name value is not displayed in the selected grid. |
| [isolation-session-b.png](evidence/isolation-session-b.png) | `session_b_pid = 753`. Tabs show `SELECT 1`, `BEGIN`, `SHOW`, `SELECT 1`, `SELECT 1`, `COMMIT`. | Confirms the script reached its reads and COMMIT on a backend different from the captured isolation A run. Neither doctor's-name result nor the SHOW value is selected. This does not prove A remained uncommitted during B's first read or that B's two reads differed. |
| [booking-session-a.png](evidence/booking-session-a.png) | `session_a_pid = 753`. Tabs show `SELECT 1`, `BEGIN`, `INSERT 1`, `COMMIT`. SQL requests P3-P-01's 1 February 2035, 09:00–09:30 WAT booking. | Confirms one appointment insert and a successful COMMIT in that run. No interleaved wait is visible. |
| [booking-session-b.png](evidence/booking-session-b.png) | `session_b_pid = 753`. Tabs show `SELECT 1`, `BEGIN`, `SET`, `ERROR`, with `Failed transaction: ROLLBACK required`. Script comments mention `doctor_schedule_no_overlap` and `23P01`. | Confirms the competing-booking script failed. The actual error tab is not selected: the constraint name and SQLSTATE are visible only in comments, not an error result. The displayed PID matches booking A, so these screenshots do not establish two independent concurrent backends. |
| [verify.png](evidence/verify.png) | Result grid contains exactly one row: patient `P3-P-01`, doctor `P3-D-01`, appointment `30015`, start `2035-02-01 09:00:00`, end `2035-02-01 09:30:00`, status `scheduled`. UI reports `1 row` and `380ms`. | Confirms the expected first booking exists and the doctor's queried day contains one appointment at verification time. The 380 ms is a UI-reported duration, not a measured lock-wait time or EXPLAIN execution time. |

### Supplementary COMMIT/ROLLBACK Verification

[commit-rollback-verification.png](evidence/commit-rollback-verification.png) displays a successful two-row verification grid:

| Check | Actual rows | Expected rows | Assessment |
|---|---:|---:|---|
| Committed booking and note | 1 | 1 | Current persisted booking/note state confirmed |
| Rolled-back booking absent | 0 | 0 | Target second booking is absent |

Both values match expectations. This resolves the missing final-count evidence from the earlier failed run screenshot. The screenshot establishes the final database state; it does not independently show the second booking existing before ROLLBACK or the full transaction sequence. The UI reports 363 ms for this verification query, not a transaction or lock-wait benchmark.

### Confirmed Final Booking

| Field | Observed value |
|---|---|
| Patient number | `P3-P-01` |
| Doctor number | `P3-D-01` |
| Appointment ID | `30015` |
| Start time (Africa/Lagos) | `2035-02-01 09:00:00` |
| End time (Africa/Lagos) | `2035-02-01 09:30:00` |
| Status | `scheduled` |
| Rows returned | `1` |

![Verified remaining appointment](evidence/verify.png)

### Interpretation

The evidence confirms a committed appointment and a final state containing one booking for the queried doctor/day. The attempted competing-booking run shows an error, but its actual error message needs to be captured before attributing that screenshot specifically to the exclusion constraint. Earlier reported `23P01` errors are consistent with overlap rejection, but are not a substitute for the missing error-detail view in this screenshot.

Isolation A uses PID 823 and isolation B uses PID 753, showing different backends at those captured executions. However, both screenshots show each script reaching COMMIT, and no before/after name result is displayed. Therefore dirty-read prevention and a nonrepeatable read remain **unverified by the supplied screenshots**.

Both booking captures display PID 753. That is compatible with sequential reuse of a connection; it does not establish two simultaneous sessions. The final one-booking state must not be described as proof that B waited for an uncommitted A transaction.

### Additional Evidence Needed

1. Final counts are now confirmed as 1 and 0 by the supplementary screenshot. For full rollback-sequence evidence, also retain the second booking visible inside its transaction before ROLLBACK; do not rerun the already committed booking.
2. Inspect setup fixtures with SELECTs and capture the two P3 patients and doctor. The existing failed setup screenshot is a troubleshooting record, not successful setup evidence.
3. Capture isolation B's actual name before A commits and again after A commits, within the same B transaction, using two persistent connections. Confirm distinct stable PIDs and the interleaving order.
4. Select booking B's actual ERROR tab and capture the message and SQLSTATE.
5. To claim simultaneous booking control, repeat with two independent persistent connections and a fresh unused test slot, updating both race scripts and the verification bounds consistently. Capture B waiting while A remains uncommitted. Do not delete the verified booking to reuse its slot.

Save supplementary screenshots with descriptive filenames and add links beside these original records. Preserve the original failure screenshots as evidence of troubleshooting.

## Troubleshooting and Safe Reruns

| Issue | Interpretation and next action |
|---|---|
| Duplicate P3 identifier | Setup may already have succeeded; inspect existing fixtures |
| `doctor_schedule_no_overlap` during COMMIT example | A matching appointment may already be committed; inspect bookings before rerunning |
| Same error during the two-session race | Expected only when caused by the competing booking; preserve the operation order as evidence |
| Transaction is aborted | Run `ROLLBACK;` in that connection before continuing |
| Zero inserted rows without an error | INSERT SELECT may not have found setup records; confirm all P3 fixtures exist |
| B never waits | Check independent connections, uncommitted A insert, matching doctor and overlapping times |
| B lock timeout | Resolve A's transaction and roll B back; do not count the timeout as the exclusion test |
| Doctor name update reports appointment overlap | Confirm the exact SQL executed; the supplied name update does not modify appointments |

Generated identity values may have gaps after rollbacks; this is normal. If abandoning an exercise, roll back open transactions in both sessions to release locks. Do not remove existing clinical records to make scripts rerunnable.

## Reflection Prompts

Write a short individual reflection covering:

- Which changes persisted after COMMIT and disappeared after ROLLBACK?
- What did each session see before and after the name update committed?
- Did B wait during the booking race, and when did the error occur?
- How did the exclusion constraint prevent double booking?
- What difficulties did session management or rerunning scripts cause?

Explain your actual observations in your own words; replace these prompts with your reflection before submission.

## AI Assistance Declaration

ChatGPT assisted with drafting the SQL scripts and documentation. The student is responsible for executing and checking the exercises, correcting issues, preserving genuine evidence, and understanding the submitted work. Document the verification performed and any corrections in the final portfolio declaration.

