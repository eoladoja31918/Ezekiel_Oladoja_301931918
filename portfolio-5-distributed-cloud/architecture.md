# Portfolio 5: Distributed and Cloud Database Architecture

**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** Hospital / Clinic Management System  
**Implemented service:** MongoDB Atlas laboratory report database  
**Database / collection:** `clinic_nosql.laboratory_reports`

## 1. Scope and Evidence Status

This portfolio combines an existing cloud database implementation with a distributed-database discussion. The assessment permits discussion or setup; it does not require every feature discussed to be deployed.

Three evidence levels are used:

- **Observed:** visible in the supplied Portfolio 4 screenshots.
- **Pending inspection:** information requested by `01-inspect-deployment.js`, whose output has not yet been supplied for review.
- **Proposed:** a future architecture or operating policy, not an implemented result.

No failover experiment, replication-lag measurement, majority-write test, or sharded collection is claimed.

## 2. Observed Cloud Deployment

| Item | Observation | Evidence / limit |
|---|---|---|
| Hosting | mongosh is connected to an Atlas deployment | Portfolio 4 screenshots show an Atlas shell prompt |
| Endpoint role | Shell prompt identifies the connection as `[primary]` | Supports the primary role at capture time; does not establish all members' health |
| Database and collection | `clinic_nosql.laboratory_reports` | Query explain command names both explicitly |
| Server version | MongoDB `8.0.34` | Visible in the query explain screenshot |
| Validation | `strict` validation and `error` action | Setup options shown |
| Indexes | Default `_id_`, unique report number, unique requested-test reference, patient-history index | Setup screenshot shows all four definitions |
| Stored documents | Completed qualitative, in-progress, and pending reports | Seed screenshot shows these examples |
| Query execution | Patient-history explain examines two index keys | Query screenshot shows bounds and `keysExamined: 2` |
| Provider, region, and tier | Not established | Requires Atlas UI evidence |
| Replica-set name, advertised hosts, and member count | Not established | Requires inspection output; hostnames alone do not prove topology |
| Majority read / default concerns | Not established | Requires inspection output; earlier operations did not explicitly demonstrate these settings |
| Sharding | Not demonstrated | No collection sharding metadata supplied |

Existing evidence links:

- [Portfolio 4 setup](../portfolio-4-nosql/evidence/01-setup.png)
- [Portfolio 4 seed documents](../portfolio-4-nosql/evidence/02-seed.png)
- [Portfolio 4 query explain](../portfolio-4-nosql/evidence/03-queries.png)

Do not infer sharding from an Atlas hostname containing the word `shard`. Deployment naming is not proof that the collection is partitioned across shards.

## 3. Current Logical Architecture

| Component | Responsibility | Implementation status |
|---|---|---|
| Neon PostgreSQL | Patients, doctors, appointments, diagnoses, prescriptions, and relational laboratory records | Earlier portfolio implementation |
| MongoDB Atlas | Document-model laboratory reports with embedded measurements | Portfolio 4 implementation |
| mongosh | Runs setup, insert, query, update, and inspection scripts | Demonstrated client |
| Clinic application / integration service | Validates references and coordinates real clinical workflows | Proposed; not implemented |

Neon and Atlas are separate data stores. The current MongoDB reports use explicitly simulated appointment and request-item references, not validated foreign keys into Neon. No automatic replication or synchronisation exists between these different databases in this project.

A production integration would require an explicit source-of-truth policy, reliable event delivery, idempotent handling, reconciliation, and access controls. It must not assume that a successful MongoDB write also commits a PostgreSQL change.

## 4. Replication

### Mechanism and Clinic Relevance

MongoDB replica sets maintain copies of data across members. Writes normally go to the primary; secondaries replicate changes. Eligible members can participate in elections when a primary becomes unavailable.

For the clinic, replication can support continued service after a member failure and can support appropriately configured secondary reads. It is different from sharding: replication copies a dataset, while sharding partitions a dataset.

### Evidence to Collect

Run [01-inspect-deployment.js](scripts/01-inspect-deployment.js) and retain its JSON output at `evidence/deployment-inspection.json`.

| Inspection field | Meaning | What it does not prove |
|---|---|---|
| `hello.setName` | Advertised replica-set identity | Actual replication lag or member health |
| `hello.isWritablePrimary` / `secondary` | Responding endpoint's advertised role | Continuous availability |
| `hello.primary` | Advertised primary address | That every listed host is reachable |
| `hello.hosts` | Members advertised for discovery | Complete failure-domain placement or tested failover |
| Optional replica status | Reported member state/health when permitted | Recovery under a simulated outage |

Some commands may be unavailable on the deployed tier or to the database user. Preserve the resulting UNAVAILABLE record as a limitation; do not interpret it as absent replication or request broader administrative rights merely to complete the exercise.

**Current conclusion:** Cloud use and a primary-labelled connection are observed. Detailed replica-set topology and health remain pending inspection.

## 5. Availability and Recovery

### Proposed Resilience Design

For a larger clinic deployment, use a supported configuration with three data-bearing voting replica-set members distributed across suitable failure domains. This is a proposal, not the observed member count or placement of the current cluster.

| Event | Intended behaviour | Limit / response |
|---|---|---|
| One member fails | Remaining eligible voting members may elect/retain a primary | Outcome depends on quorum, reachability, and placement |
| Election occurs | Client discovers the new primary | A temporary interruption or error is possible |
| Majority is unavailable | Majority-dependent operations cannot proceed normally | Do not acknowledge a clinical write as successful without the required confirmation |
| Client loses its connection | Reconnect and retry only under defined retry semantics | Use stable request/report identifiers to prevent duplicate creation |
| Accidental deletion or corruption | Restore from independently tested backups | Replication alone is not a backup |

Do not claim zero downtime, a recovery time objective, or a recovery point objective without tests and a defined configuration. Backup availability and retention must be verified for the actual Atlas tier.

The inspection script does not stop members, force elections, alter deployment settings, or measure outage recovery. Availability discussion therefore remains architectural rather than experimental.

## 6. Consistency Policy

Read preference, read concern, and write concern address different questions:

| Setting | Question answered | Proposed clinic policy |
|---|---|---|
| Read preference | Which eligible member should serve a read? | Primary for active clinical reporting |
| Read concern | What visibility/commitment conditions must a read satisfy? | Majority for committed report data |
| Write concern | What acknowledgement must a write receive? | Majority, with a finite timeout and explicit error handling |
| Causally consistent session | How are related operations ordered for a client session? | Consider for read-your-own-writes workflows with suitable majority concerns |

A secondary can serve a lagging view. Historical analytics may tolerate that under a documented policy; current report-completion workflows should not silently accept stale state.

A successful majority read does not by itself establish the latest possible value or linearizable behaviour. Likewise, reading from a primary alone is not a universal consistency guarantee. A majority-write timeout leaves the write outcome potentially uncertain; inspect or reconcile by a unique operation identifier rather than assuming nothing was written.

### Current Implementation Boundary

Portfolio 4 updates completion fields within one report document, providing a single-document atomic update boundary. The update filter checks the report's pending state before applying the completion. That is not a multi-database transaction.

The inspection script includes a read-only `readConcern: { level: "majority" }` request. If acknowledged, retain its actual result as evidence of that operation only. Default-concern inspection, if permitted, does not prove which concerns earlier clients used.

No explicit majority-write acknowledgement or causal-session test has yet been evidenced.

## 7. Proposed Sharding Strategy — Not Implemented

### When to Consider It

Five reports do not justify sharding. First measure storage growth, workload, index effectiveness, latency, and the limits of a replica-set deployment. Sharding adds routing, balancing, operational costs, and integrity constraints.

If growth eventually warrants sharding, the main access pattern is patient report history. One candidate is:

```javascript
// Design example only. This file does not execute a sharding command.
{ patient_number: "hashed" }
```

Hashing patient identifiers can spread different patients across shards while allowing equality queries containing the patient shard key to target the relevant shard. It does not split one exceptionally large patient's workload across shards, and a cross-patient pending queue may require scatter/gather work.

### Candidate Comparison

| Candidate | Potential benefit | Main concern |
|---|---|---|
| Hashed `patient_number` | Distributes patients and supports patient-specific routing | Hot individual patients; global queues; existing unique-index incompatibility |
| Ranged `requested_at` | Supports time-range locality | Increasing timestamps can concentrate incoming writes on the newest range |
| Branch-only key | Branch-based locality if a branch field is introduced | Few branches, uneven load, and insufficient granularity; current model has no branch field |

No candidate is approved for deployment solely from this small demonstration dataset.

### Critical Unique-Index Constraint

The current collection has separate global unique indexes on `report_number` and `request_item_id`. They do not include the proposed patient shard key. MongoDB's sharded unique-index rules mean that the existing collection cannot simply be sharded on this candidate while retaining those indexes unchanged. A hashed index itself cannot be declared unique.

Adding patient number to a compound unique index would change its scope to patient-plus-identifier; that alone would not preserve the current globally unique report and requested-test semantics.

Before implementing this proposal, resolve uniqueness explicitly. One possible future design is a separately maintained unsharded identifier registry with unique report and request-item keys, coordinated with report creation through an appropriate transactional workflow supported by the selected deployment. That registry introduces its own capacity and availability dependency and is not implemented here. Other shard-key or identifier designs may be preferable after workload and integrity analysis.

Do not drop the existing unique indexes or run sharding commands in the educational cluster as part of this document.

### Proposed Sharded Components

| Component | Future role |
|---|---|
| `mongos` routers | Route requests to relevant shards |
| Config-server replica set | Maintain sharding metadata |
| Shard replica sets | Store partitions with replicated copies |
| Identifier-integrity mechanism | Preserve required global business uniqueness |

The provider, region, tier, shard key, uniqueness redesign, cost, and migration plan must be validated before such a deployment. Sharding capability is not assumed for the current Atlas cluster.

## 8. Deployment Evidence and Remaining Work

| Evidence | Purpose | Status |
|---|---|---|
| Existing Portfolio 4 screenshots | Show cloud-hosted documents, validation, indexes, and execution | Reviewed |
| `evidence/deployment-inspection.json` | Capture topology, counts, optional status, and majority-read result | Pending upload/review |
| Atlas cluster screenshot | Confirm tier, provider, region, and configuration shown | Pending |
| Failover or outage results | Establish recovery behaviour | Not performed; no claim made |
| Sharding results | Establish actual partitioning | Not performed; proposal only |

Keep errors, denied commands, and missing fields in the inspection evidence rather than replacing them with expected values. Deployment screenshots should omit passwords and credential-bearing connection strings.

## 9. Summary and Reflection

The implemented clinic report service demonstrates managed cloud database use. Replication and concern policies explain how a larger deployment could improve resilience and control data visibility, but they must be grounded in actual configuration and tests. Sharding is a future scaling option whose choice is constrained by both query patterns and unique identifiers.

A central lesson is that cloud hosting, replication, high availability, and sharding are distinct claims. A successful query demonstrates access at one moment; it does not demonstrate failover. A replica-set name supports topology identification; it does not prove every member's health. A proposed shard key is incomplete until uniqueness and workload distribution are addressed.

Add an individual reflection on the actual inspection results, unavailable commands, and design decisions after collecting the pending evidence.

## References

Official MongoDB documentation consulted for the architecture discussion:

1. [hello command and discovery fields](https://www.mongodb.com/docs/manual/reference/command/hello/)
2. [Atlas unsupported commands](https://www.mongodb.com/docs/atlas/unsupported-commands/)
3. [Read preference use cases](https://www.mongodb.com/docs/manual/core/read-preference-use-cases/)
4. [Unique indexes and sharded restrictions](https://www.mongodb.com/docs/manual/core/index-unique/)
5. [Shard-key index requirements](https://www.mongodb.com/docs/manual/core/sharding-shard-key-indexes/)
6. [Hashed sharding](https://www.mongodb.com/docs/manual/core/hashed-sharding/)

ChatGPT assisted with drafting and technical synthesis. Observations are limited to the evidence identified above; the student remains responsible for validating the deployment and explaining the submitted work.
