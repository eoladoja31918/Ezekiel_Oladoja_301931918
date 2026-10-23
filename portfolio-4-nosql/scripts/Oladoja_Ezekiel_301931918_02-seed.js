// MIT 8103 Portfolio 4: fictional clinic laboratory reports.
// Run AFTER 01-setup.js, in mongosh connected to Atlas:
// load("C:/Users/YOUR_NAME/Downloads/02-seed.js")
// This script inserts five reports. It never deletes or overwrites existing data.
// IMPORTANT: appointment_id and request_item_id below are SIMULATED references,
// not verified PostgreSQL foreign keys. This is a standalone NoSQL demonstration.
// Patient numbers reuse the clinic case study; no cross-database lookup occurs.
// Values are fictional and must not be used for clinical interpretation.

(() => {
  const clinic = db.getSiblingDB("clinic_nosql");
  const collectionName = "laboratory_reports";
  const info = clinic.getCollectionInfos({ name: collectionName })[0];
  if (!info) throw new Error("Run 01-setup.js first: laboratory_reports does not exist.");
  if (!info.options.validator || info.options.validationLevel !== "strict" ||
      info.options.validationAction !== "error") {
    throw new Error("Expected strict/error validation is missing. Inspect setup before inserting.");
  }
  const reports = clinic.getCollection(collectionName);
  const indexes = reports.getIndexes();
  for (const field of ["report_number", "request_item_id"]) {
    if (!indexes.some(i => i.unique === true && i.key[field] === 1 &&
                         Object.keys(i.key).length === 1)) {
      throw new Error("Required unique index is missing for " + field);
    }
  }

  // Use BSON Int32 for schema_version to match the collection validator.
  // Pending/in-progress documents omit reported_at until completion.
  const samples = [
    {
      report_number: "P4-LAB-0001",
      schema_version: Int32(1),
      patient_number: "PAT001",
      appointment_id: "901001",
      request_item_id: "902001",
      test: { code: "FBC", name: "Full Blood Count" },
      status: "completed",
      requested_at: ISODate("2026-10-19T08:20:00Z"),
      reported_at: ISODate("2026-10-19T10:00:00Z"),
      measurements: [
        { code: "HB", name: "Haemoglobin", value: 13.5, unit: "g/dL" },
        { code: "WBC", name: "White blood cell count", value: 6.2, unit: "10^9/L" }
      ],
      comments: "Fictional numeric report; appointment and requested-test references are simulated."
    },
    {
      report_number: "P4-LAB-0002",
      schema_version: Int32(1),
      patient_number: "PAT001",
      appointment_id: "901002",
      request_item_id: "902002",
      test: { code: "GLU", name: "Demo Glucose Test" },
      status: "pending",
      requested_at: ISODate("2026-10-20T08:00:00Z"),
      measurements: [],
      comments: "Pending report reserved for the later completion/update exercise. References are simulated."
    },
    {
      report_number: "P4-LAB-0003",
      schema_version: Int32(1),
      patient_number: "P2-P-00002",
      appointment_id: "901003",
      request_item_id: "902003",
      test: { code: "QUAL", name: "Demo Qualitative Test" },
      status: "completed",
      requested_at: ISODate("2026-10-19T09:00:00Z"),
      reported_at: ISODate("2026-10-19T11:00:00Z"),
      measurements: [
        { code: "FINDING", name: "Demo finding", value: "not detected" }
      ],
      comments: "Fictional qualitative result with no unit. References are simulated."
    },
    {
      report_number: "P4-LAB-0004",
      schema_version: Int32(1),
      patient_number: "P2-P-00002",
      appointment_id: "901004",
      request_item_id: "902004",
      test: { code: "RENAL", name: "Demo Kidney Panel" },
      status: "in-progress",
      requested_at: ISODate("2026-10-20T10:00:00Z"),
      measurements: [],
      comments: "Processing has begun; measurements and reporting date are not yet available. References are simulated."
    },
    {
      report_number: "P4-LAB-0005",
      schema_version: Int32(1),
      patient_number: "P2-P-00003",
      appointment_id: "901005",
      request_item_id: "902005",
      test: { code: "LIVER", name: "Demo Liver Panel" },
      status: "pending",
      requested_at: ISODate("2026-10-20T11:00:00Z"),
      measurements: [],
      comments: "Second pending report for work-queue queries. References are simulated."
    }
  ];

  const reportNumbers = samples.map(s => s.report_number);
  const requestIds = samples.map(s => s.request_item_id);

  // Refuse a duplicate or partial rerun rather than silently modifying reports.
  const conflicts = reports.find({
    $or: [
      { report_number: { $in: reportNumbers } },
      { request_item_id: { $in: requestIds } }
    ]
  }, { _id: 0, report_number: 1, request_item_id: 1 }).toArray();
  if (conflicts.length > 0) {
    print("Existing conflicting reports:");
    printjson(conflicts);
    throw new Error("Seed identifiers already exist. Inspect existing data; do not rerun or delete blindly.");
  }

  // insertMany is NOT atomic across documents. Ordered insertion stops on the
  // first error; earlier documents may remain. A failure needs inspection.
  const result = reports.insertMany(samples, { ordered: true });
  print("Insert acknowledgement:");
  printjson(result);

  // Verify saved batch, not the whole collection (which may have other reports).
  const stored = reports.find({ report_number: { $in: reportNumbers } })
    .sort({ report_number: 1 }).toArray();
  if (stored.length !== samples.length) {
    throw new Error("Seed count verification failed: expected 5, found " + stored.length);
  }
  const counts = { completed: 0, pending: 0, "in-progress": 0 };
  for (const report of stored) {
    counts[report.status] = (counts[report.status] || 0) + 1;
  }
  if (counts.completed !== 2 || counts.pending !== 2 || counts["in-progress"] !== 1) {
    throw new Error("Seed status verification failed: " + EJSON.stringify(counts));
  }

  print("SEED VERIFIED: five fictional reports inserted.");
  print("Expected batch statuses: completed=2, pending=2, in-progress=1.");
  printjson(counts);
  print("Stored reports (capture this actual output as evidence):");
  printjson(stored);
  print("No PostgreSQL reference existence or consistency checks were performed.");
  print("Next: 03-queries.js will retrieve reports and complete P4-LAB-0002.");
})();
