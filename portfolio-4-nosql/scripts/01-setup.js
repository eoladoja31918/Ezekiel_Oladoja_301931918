// MIT 8103 Portfolio 4: Clinic laboratory report collection setup.
// Run in mongosh connected to your MongoDB Atlas cluster, NOT in Neon.
// Example inside mongosh (adjust the local path):
// load("C:/Users/YOUR_NAME/Downloads/01-setup.js")
// Run once. No sample reports are inserted and no existing collection is dropped.
// This file creates a collection and three indexes; these DDL operations are
// not one transaction. If an operation fails, inspect the state before retrying.

(() => {
  const clinic = db.getSiblingDB("clinic_nosql");
  const collectionName = "laboratory_reports";

  // Do not silently overwrite an existing validator, collection, or report data.
  if (clinic.getCollectionInfos({ name: collectionName }).length > 0) {
    throw new Error(
      "clinic_nosql.laboratory_reports already exists. " +
      "Inspect its validator and indexes before making changes; do not drop it."
    );
  }

  // Each mandatory string must contain at least one non-whitespace character.
  const nonblank = { bsonType: "string", pattern: "\\S" };
  // Positive PostgreSQL BIGINT references are stored as strings, not JS Numbers.
  const externalId = { bsonType: "string", pattern: "^[1-9][0-9]*$" };

  const documentSchema = {
    bsonType: "object",
    additionalProperties: false,
    required: [
      "report_number", "schema_version", "patient_number", "appointment_id",
      "request_item_id", "test", "status", "requested_at", "measurements"
    ],
    properties: {
      _id: { bsonType: "objectId" },
      report_number: nonblank,
      schema_version: { bsonType: "int", enum: [1] },
      patient_number: nonblank,
      appointment_id: externalId,
      request_item_id: externalId,
      test: {
        bsonType: "object",
        additionalProperties: false,
        required: ["code", "name"],
        properties: { code: nonblank, name: nonblank }
      },
      status: {
        bsonType: "string",
        enum: ["pending", "in-progress", "completed", "cancelled"]
      },
      requested_at: { bsonType: "date" },
      // Omit this field before completion rather than setting it to null.
      reported_at: { bsonType: "date" },
      measurements: {
        bsonType: "array",
        items: {
          bsonType: "object",
          additionalProperties: false,
          required: ["code", "name", "value"],
          properties: {
            code: nonblank,
            name: nonblank,
            value: {
              anyOf: [
                { bsonType: ["int", "long", "double", "decimal"] },
                nonblank
              ]
            },
            unit: nonblank
          }
        }
      },
      comments: { bsonType: "string" }
    }
  };

  const validator = {
    $and: [
      { $jsonSchema: documentSchema },

      // A completed report requires a BSON reporting date and >= 1 measurement.
      // Pending/in-progress/cancelled reports may retain an empty array.
      {
        $or: [
          { status: { $ne: "completed" } },
          {
            $jsonSchema: {
              required: ["reported_at", "measurements"],
              properties: {
                reported_at: { bsonType: "date" },
                measurements: { bsonType: "array", minItems: 1 }
              }
            }
          }
        ]
      },

      // Compare dates only when both fields are dates. Schema validation
      // separately rejects incorrect types or missing mandatory date fields.
      {
        $expr: {
          $cond: [
            {
              $and: [
                { $eq: [{ $type: "$reported_at" }, "date"] },
                { $eq: [{ $type: "$requested_at" }, "date"] }
              ]
            },
            { $gte: ["$reported_at", "$requested_at"] },
            true
          ]
        }
      },

      // Measurement codes must be distinct WITHIN a report.
      // uniqueItems on whole objects alone would not enforce code uniqueness.
      {
        $expr: {
          $cond: [
            { $isArray: "$measurements" },
            {
              $let: {
                vars: {
                  codes: {
                    $map: { input: "$measurements", as: "m", in: "$$m.code" }
                  }
                },
                in: {
                  $eq: [
                    { $size: "$$codes" },
                    { $size: { $setUnion: ["$$codes", []] } }
                  ]
                }
              }
            },
            // The schema rejects a missing or non-array measurements field.
            true
          ]
        }
      }
    ]
  };

  // Reject invalid documents on both inserts and updates.
  const created = clinic.createCollection(collectionName, {
    validator,
    validationLevel: "strict",
    validationAction: "error"
  });
  if (created.ok !== 1) {
    throw new Error("Collection creation failed: " + EJSON.stringify(created));
  }

  const reports = clinic.getCollection(collectionName);

  // Unique report business identifier.
  reports.createIndex(
    { report_number: 1 },
    { name: "uq_report_number", unique: true }
  );

  // This version allows exactly one current report per requested test.
  reports.createIndex(
    { request_item_id: 1 },
    { name: "uq_request_item_id", unique: true }
  );

  // Patient history: newest request first, with a stable report-number tie-break.
  reports.createIndex(
    { patient_number: 1, requested_at: -1, report_number: 1 },
    { name: "ix_patient_report_history" }
  );

  // Verify saved configuration rather than printing an unconditional PASS.
  const info = clinic.getCollectionInfos({ name: collectionName })[0];
  const indexes = reports.getIndexes();
  const expected = [
    { name: "uq_report_number", key: { report_number: 1 }, unique: true },
    { name: "uq_request_item_id", key: { request_item_id: 1 }, unique: true },
    {
      name: "ix_patient_report_history",
      key: { patient_number: 1, requested_at: -1, report_number: 1 },
      unique: false
    }
  ];

  for (const expectedIndex of expected) {
    const actual = indexes.find(index => index.name === expectedIndex.name);
    if (!actual || JSON.stringify(actual.key) !== JSON.stringify(expectedIndex.key) ||
        Boolean(actual.unique) !== expectedIndex.unique) {
      throw new Error("Index verification failed: " + expectedIndex.name);
    }
  }
  if (info.options.validationLevel !== "strict" ||
      info.options.validationAction !== "error" || !info.options.validator) {
    throw new Error("Collection validation configuration is not as expected.");
  }

  print("SETUP VERIFIED: clinic_nosql.laboratory_reports");
  print("Collection options (save as implementation evidence):");
  printjson(info.options);
  print("Indexes: expect _id_ plus the three application indexes:");
  printjson(indexes);
  print("Document count (zero on a fresh setup): " + reports.countDocuments({}));
  print("Next: run 02-seed.js after reviewing the sample data.");
})();

// LIMITATIONS:
// External identifiers are format-checked, not verified against PostgreSQL.
// No automatic cross-database synchronisation or clinical approval is provided.
// Index listing confirms configuration, not query-performance improvement.
// Record execution output; this script has not been run against your Atlas here.
