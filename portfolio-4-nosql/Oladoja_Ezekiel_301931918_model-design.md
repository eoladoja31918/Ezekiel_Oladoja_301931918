# Portfolio 4: Clinic Laboratory Report Document Model

**Course:** MIT 8103 — Advanced Database Systems  
**Case study:** Hospital / Clinic Management System  
**Database:** `clinic_nosql`  
**Collection:** `laboratory_reports`  
**NoSQL model:** Document database using MongoDB

## 1. Purpose and Assessment Mapping

This model represents laboratory reports for the same clinic used in Portfolios 1–3. It demonstrates one NoSQL model; implementing key-value, column-family, and graph databases as well is outside this exercise's scope.

| Assessment requirement | Planned response |
|---|---|
| Model based on the same case study | Reports reference clinic patients, appointments, and requested tests |
| Document/key-value/column/graph example | MongoDB report documents with embedded measurements |
| Implementation evidence | Collection validation, sample documents, queries, updates, and actual outputs |
| Explanation of suitability | Embedding, flexible measurements, reference integrity, and SQL/NoSQL trade-offs |

**Status:** Design specification. No collection creation or execution evidence is claimed in this document.

## 2. Scope and Document Boundary

Each document represents **one laboratory report for one requested test**. A requested test may be a panel containing several result measurements. Multiple tests on a laboratory request are represented by separate report documents.

For example, a full blood count report can contain haemoglobin and white-cell measurements, while a qualitative test can contain a string-valued finding. Both use the same report structure.

The database supports:

- Recording a pending report and completing it later.
- Retrieving a patient's reports, newest first.
- Finding reports by status or test code.
- Searching measurements within reports.
- Updating a report's measurements, status, and reporting timestamp together.

Only synthetic data will be used. Patient registration, scheduling, diagnoses, and prescriptions remain in PostgreSQL. Cross-database synchronisation is not implemented by this portfolio.

## 3. Example Completed Document

The following uses **mongosh syntax**, not strict JSON. `ObjectId`, `Int32`, and `ISODate` create BSON values. The external appointment and request-item IDs are illustrative placeholders and must be replaced or explicitly labelled as simulated references during implementation.

```javascript
{
  _id: ObjectId("507f1f77bcf86cd799439011"),
  report_number: "P4-LAB-0001",
  schema_version: Int32(1),
  patient_number: "PAT001",
  appointment_id: "501",
  request_item_id: "201",
  test: {
    code: "FBC",
    name: "Full Blood Count"
  },
  status: "completed",
  requested_at: ISODate("2026-10-19T08:20:00Z"),
  reported_at: ISODate("2026-10-19T10:00:00Z"),
  measurements: [
    {
      code: "HB",
      name: "Haemoglobin",
      value: 13.5,
      unit: "g/dL"
    },
    {
      code: "WBC",
      name: "White blood cell count",
      value: 6.2,
      unit: "10^9/L"
    }
  ],
  comments: "Fictional measurements for database demonstration."
}
```

A pending report uses `status: "pending"` and `measurements: []`; it omits `reported_at` until completion. A qualitative measurement can use a value such as `"not detected"`, omitting the unit where inappropriate.

## 4. Field Definitions

| Field | BSON type | Requirement and meaning |
|---|---|---|
| `_id` | ObjectId | Unique document identifier; generated when omitted on insertion |
| `report_number` | String | Required, nonblank, unique report identifier |
| `schema_version` | Int32 | Required; value `1` for this version |
| `patient_number` | String | Required, nonblank patient reference |
| `appointment_id` | String | Required positive decimal identifier for the originating appointment |
| `request_item_id` | String | Required positive decimal identifier for the requested test; unique |
| `test` | Object | Required test snapshot |
| `test.code` | String | Required, nonblank catalogue code |
| `test.name` | String | Required, nonblank test name at report creation |
| `status` | String | Required: `pending`, `in-progress`, `completed`, or `cancelled` |
| `requested_at` | Date | Required request timestamp |
| `reported_at` | Date | Optional before completion; mandatory when completed |
| `measurements` | Array of objects | Required; may be empty before completion |
| `measurements[].code` | String | Required, nonblank; unique within the report |
| `measurements[].name` | String | Required, nonblank measurement name |
| `measurements[].value` | Numeric or string | Required quantitative value or nonblank qualitative finding |
| `measurements[].unit` | String | Optional; nonblank when present |
| `comments` | String | Optional explanatory text |

PostgreSQL BIGINT references are decimal strings to avoid JavaScript Number precision loss. BSON dates represent instants; the examples use explicit UTC timestamps. Display can be converted to Africa/Lagos without changing the stored instant.

## 5. Business and Validation Rules

| Rule | Planned enforcement |
|---|---|
| Required fields, BSON types, status enum and nonblank strings | Collection `$jsonSchema` validation |
| Schema version equals 1 | Collection validation |
| IDs contain positive decimal digits | String pattern validation |
| Report numbers are unique | Unique index |
| One report per requested test | Unique index on `request_item_id` |
| Completed report has at least one measurement and a reporting date | Conditional validator combining schema rules and/or expressions |
| Reporting date, when present, does not precede request date | Cross-field validation expression |
| Measurement codes do not repeat inside a document | Validation expression comparing codes and their distinct set |
| Referenced PostgreSQL records exist and belong together | Explicit lookup/import checks outside MongoDB; no cross-database foreign key |
| Status changes follow the intended workflow | Update script filters on current status; collection validation checks the resulting document |

JSON Schema `uniqueItems` alone is not sufficient to make measurement **codes** unique: two different objects could share the same code. The implementation must check the codes themselves.

A completed report should be written using one document update that sets measurements, status, and `reported_at` together. The validator checks the resulting document. No clinical approval or amendment-history workflow is claimed.

## 6. Embedding and References

| Information | Design choice | Reason |
|---|---|---|
| Measurements | Embedded array | Bounded results belong to one report and are normally read together |
| Test code and name | Embedded snapshot | Keeps the report's test description stable after catalogue changes |
| Patient | Reference using `patient_number` | Avoids copying names, addresses, and contact details into every report |
| Appointment | Reference using `appointment_id` | Connects the report to the originating consultation |
| Requested test | Reference using `request_item_id` | Connects the report to the specific test occurrence |

The test snapshot is deliberate duplication. A later catalogue correction does not automatically overwrite existing reports. Reference checks must also verify that the patient, appointment, and requested test are related correctly, rather than merely checking that each identifier exists.

For this exercise, reference identifiers are treated as stable. Changes to PostgreSQL identifiers would require coordinated updates. MongoDB and PostgreSQL are separate systems; a MongoDB update does not commit changes in PostgreSQL.

## 7. Index Design

| Index | Definition | Purpose |
|---|---|---|
| Default primary identifier | `_id` | Unique document lookup |
| Unique report number | `{ report_number: 1 }` | Reject duplicate report identifiers |
| Unique requested-test reference | `{ request_item_id: 1 }` | Enforce the one-report-per-requested-test boundary |
| Patient report history | `{ patient_number: 1, requested_at: -1, report_number: 1 }` | Filter by patient and sort newest first with a deterministic tie-breaker |

No status or measurement index is assumed necessary for a small sample. Index usage and any performance claims must be supported by actual explain output. Indexes incur storage and write-maintenance costs.

## 8. Planned Operations and Evidence

| Operation | Demonstration | Evidence |
|---|---|---|
| Create | Create collection validator and indexes | Setup output, collection options, index listing |
| Insert | Load completed, pending, and qualitative fictional reports | Insert acknowledgement and displayed documents |
| Read patient history | Filter patient and sort by request date descending, report number ascending | Actual returned documents |
| Read work queue | Filter pending reports | Actual pending documents |
| Search test/measurement | Filter test code or matching measurement | Results showing the matching document |
| Update | Complete a pending report in one atomic document update | Matched/modified counts and before/after document |
| Validate | Attempt duplicate report and invalid completed report inserts | Actual duplicate-key and validation rejection outputs |

For predicates on both a measurement code and its value, use `$elemMatch` to apply the conditions to the same array element. For example:

```javascript
db.laboratory_reports.find({
  measurements: {
    $elemMatch: { code: "HB", value: { $gt: 13 } }
  }
});
```

The threshold is an arbitrary database-filter example, not a clinical interpretation. Searching numeric values requires consistent units and measurement definitions; the query alone does not provide that standardisation.

## 9. Suitability and Relational Comparison

A laboratory report is a natural document boundary: its test snapshot and measurements form a self-contained read unit. Embedded arrays accommodate varying measurement counts without adding columns for each test-specific result. A validated common structure preserves consistency while permitting numeric and qualitative findings.

| Aspect | PostgreSQL clinic model | MongoDB report model |
|---|---|---|
| Measurements | Separate rows in `laboratory_results` | Embedded objects in `measurements` |
| Complete report retrieval | Joins across relevant tables | One report document |
| Relationships | Foreign keys within PostgreSQL | References checked by scripts/application |
| Test description | Catalogue row | Embedded historical snapshot |
| Update boundary | Transaction across relevant rows | Atomic update within one document |
| Main cost | Joins and relational mapping | Snapshot duplication and external-reference coordination |

PostgreSQL remains suitable for structured clinic relationships. MongoDB provides an alternative model for report retrieval; the exercise does not establish that it is universally faster or preferable.

## 10. Limitations and Completion Criteria

- No live PostgreSQL–MongoDB synchronisation, distributed transaction, or automatic reference repair.
- One current report per requested test; revisions, approvals, and clinical audit history are not implemented.
- Embedded measurements are assumed bounded. Unbounded arrays and large attachments would require a different design.
- Mixed numeric and qualitative values require careful query predicates; reference intervals and clinical rules are outside scope.
- The implementation uses fictional data and is not a production medical-record system.

The design stage is complete when fields, document boundaries, validation responsibilities, indexes, and suitability are understood. Portfolio 4 is complete only after scripts have been executed, actual evidence saved, and results explained in the README.

**Planned files:** `scripts/01-setup.js`, `scripts/02-seed.js`, `scripts/03-queries.js`, and `evidence/`.
