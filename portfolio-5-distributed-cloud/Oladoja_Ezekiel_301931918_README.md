# Portfolio 5: Distributed and Cloud Database Exercise

**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** Hospital / Clinic Management System  
**Service:** MongoDB Atlas — `clinic_nosql.laboratory_reports`

## Objective

Document the clinic's deployed cloud database, inspect replica-set topology and report data, and discuss replication, availability, consistency, and future sharding. This submission combines actual deployment evidence with a clearly labelled architecture proposal. It does not claim a failover or sharding experiment.

## Files and Assessment Mapping

| Requirement / purpose | File |
|---|---|
| Distributed/cloud discussion | [architecture.md](architecture.md) |
| Read-only inspection implementation | [01-inspect-deployment.js](scripts/01-inspect-deployment.js) |
| Actual deployment evidence | [deployment-inspection.json](evidence/deployment-inspection.json) |
| Clinic document implementation | [Portfolio 4 README](../portfolio-4-nosql/README.md) |

The architecture explains replication, availability, consistency, and a proposed sharding strategy. The JSON establishes actual topology, member status, collection configuration, counts, and one explicit majority-read result. Upload the files at these exact relative paths.

## Execution

1. Connect mongosh to the same Atlas deployment used for Portfolio 4.
2. Load the script, adjusting its local path:

```javascript
load("C:/Users/Ezekiel Oladoja/Downloads/clinic-deployment-inspection/01-inspect-deployment.js")
```

3. Copy the JSON between `BEGIN DEPLOYMENT EVIDENCE JSON` and `END DEPLOYMENT EVIDENCE JSON`, excluding those labels.
4. Save it as `evidence/deployment-inspection.json` and preserve the actual output, including unavailable sections.

The script reads deployment information. It does not insert or modify reports, change indexes or settings, stop members, trigger elections, or enable sharding. Some inspection commands may be restricted; do not widen permissions merely to replace an unavailable result.

## Observed Deployment Results

The supplied inspection was captured on **21 October 2026 at approximately 22:19 WAT (21:19 UTC)**. It contains **10 OBSERVED sections and 1 UNAVAILABLE section**.

| Check | Actual finding |
|---|---|
| Connectivity | Ping acknowledged with `ok: 1` |
| MongoDB version | `8.0.34` |
| Replica-set name | `atlas-2t8ax2-shard-0` |
| Advertised members | Three |
| Responding node | Writable primary, `secondary: false` |
| Member health | One PRIMARY and two SECONDARY; each reports `health: 1` |
| Database | `clinic_nosql`, one collection, five documents |
| Validation | `validationLevel: strict`, `validationAction: error` |
| Indexes | Four, including both unique business-key indexes and patient-history index |
| Status counts | Completed 3, in-progress 1, pending 1 |
| Explicit majority read | Acknowledged; returned completed report `P4-LAB-0002` |
| Default-concern inspection | UNAVAILABLE: code 59, `CommandNotFound`, message `command not found` |

### Replica Member Snapshot

Host suffixes identify the members listed in the complete JSON without unnecessarily repeating full addresses.

| Member suffix | Role | Health | Operation time (UTC) |
|---|---|---:|---|
| `00-00` | SECONDARY | 1 | 21:19:32 |
| `00-01` | PRIMARY, responding member | 1 | 21:19:33 |
| `00-02` | SECONDARY | 1 | 21:19:32 |

The one-second timestamp difference is one observation, not a measured sustained replication lag. These reported states do not establish failure-domain placement, continuous availability, or recovery time.

### Collection and Consistency Evidence

The inspection shows the actual validator and these indexes:

- `_id_`
- `uq_report_number` — unique
- `uq_request_item_id` — unique
- `ix_patient_report_history` — patient number, descending request date, report number

The explicit majority read returned `P4-LAB-0002` as `completed`, requested at **20 October 2026 08:00 UTC** and reported at **10:00 UTC**. This also supplies supplementary current-state evidence for Portfolio 4. The grouped count confirms the expected post-update totals, but does not reconstruct the original before/after update acknowledgement.

The majority read demonstrates the requested read concern for that operation. It does not prove latest-write freshness, linearizability, or majority acknowledgement of earlier writes. The unavailable default-concern command does not prove defaults are absent; its precise restriction cause was not established.

## Architectural Interpretation

- **Replication:** Replica-set discovery and status confirm an observed primary/secondary topology. Secondaries maintain replicated data; this inspection did not test recovery from a failed member.
- **Availability:** A suitably configured replica set can elect a replacement primary when quorum and eligibility permit. Applications must handle interruption and uncertain outcomes. Replication is not a backup.
- **Consistency:** Primary reads, majority read/write concerns, and appropriate session semantics are proposed for active reporting workflows. Read preference, read concern, and write concern are distinct controls.
- **Cloud deployment:** Atlas hosts the documents and exposes the inspected replica set. Provider, region, tier, voting configuration, and failure-domain placement are not established by this JSON.
- **Sharding:** A patient-based hashed shard key is discussed as a future option, not enabled. The current unique indexes are incompatible with simply applying that shard key unchanged. Global identifier integrity must be redesigned explicitly before implementation.

See `architecture.md` for trade-offs, the uniqueness limitation, the scaling proposal, and official documentation references. An Atlas name containing `shard` is not proof that this collection is sharded.

## Limitations and Remaining Evidence

No failover, network partition, outage recovery, backup restoration, or majority-write test was performed. A successful read is an observation at one moment, not an availability SLA. The five-document dataset does not justify sharding or production performance claims.

An Atlas UI screenshot showing tier, provider, and region is still needed to document those properties. Save it as `evidence/atlas-cluster.png` if collected and add a link here. Omit passwords and credential-bearing connection strings.

Simulated PostgreSQL references from Portfolio 4 remain simulated; the inspection does not create cross-database replication or validate reference integrity.

## Reflection

I deployed a clinic laboratory-report database on MongoDB Atlas and inspected its topology, validation settings, indexes, and report counts. The inspection showed one healthy primary and two healthy secondaries, helping me understand how replica sets support redundancy. A successful majority read demonstrated access to majority-committed report data, but did not prove latest-write freshness or failover capability. When the default-concern command was unavailable, I documented the limitation rather than assuming its settings. Sharding remains a proposal because the five-report dataset does not justify its complexity, and the existing unique indexes require further design consideration. I did not test failover or implement sharding..

## AI Assistance

ChatGPT assisted with scripting, evidence interpretation, and documentation. The student remains responsible for reviewing and explaining the implementation and including the required AI-use declaration.


