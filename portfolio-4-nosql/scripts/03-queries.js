// MIT 8103 Portfolio 4: query and update laboratory report documents.
// Prerequisites: 01-setup.js and 02-seed.js completed successfully.
// Run in mongosh connected to Atlas, not Neon:
// load("C:/Users/YOUR_NAME/Downloads/03-queries.js")
// Only P4-LAB-0002 is updated. No documents are deleted.
// First run: pending -> completed. Later runs keep an already-completed report.
// All values are fictional, not clinical advice. References remain simulated.

(() => {
  const clinic = db.getSiblingDB("clinic_nosql");
  const name = "laboratory_reports";
  if (clinic.getCollectionInfos({ name }).length === 0) {
    throw new Error("Run 01-setup.js before this script.");
  }
  const reports = clinic.getCollection(name);
  const batch = ["P4-LAB-0001", "P4-LAB-0002", "P4-LAB-0003", "P4-LAB-0004", "P4-LAB-0005"];
  if (reports.countDocuments({ report_number: { $in: batch } }) !== 5) {
    throw new Error("Expected five P4 seed reports. Inspect 02-seed.js output before continuing.");
  }

  const output = (title, documents) => {
    print("\n=== " + title + " ===");
    print("Returned documents: " + documents.length);
    printjson(documents);
  };

  // Q1: Patient history. Index matches equality filter and the sort order.
  output("Q1: PAT001 report history, newest request first",
    reports.find({ patient_number: "PAT001" })
      .sort({ requested_at: -1, report_number: 1 }).toArray());
  // Expected seed reports: P4-LAB-0002, then P4-LAB-0001.

  // Q2: Work queue BEFORE the update. Limit scope to this known seed batch.
  output("Q2: Pending P4 reports BEFORE update",
    reports.find({ report_number: { $in: batch }, status: "pending" })
      .sort({ requested_at: 1, report_number: 1 }).toArray());
  // First run: P4-LAB-0002 and P4-LAB-0005. Later runs: P4-LAB-0005 only.

  // Q3: Query a nested field using dot notation.
  output("Q3: Completed full blood count reports",
    reports.find({ status: "completed", "test.code": "FBC" })
      .sort({ requested_at: -1, report_number: 1 }).toArray());
  // The seed contains P4-LAB-0001 with two embedded measurements.

  // Q4: Match code AND numeric threshold on the SAME measurement object.
  output("Q4: Reports with HB measurement greater than 13",
    reports.find({
      measurements: { $elemMatch: { code: "HB", value: { $gt: 13 } } }
    }).sort({ report_number: 1 }).toArray());
  // Seed match: P4-LAB-0001. Threshold is arbitrary, not a clinical conclusion.

  // Q5: Qualitative result search; no measurement unit is required here.
  output("Q5: Reports containing the qualitative finding 'not detected'",
    reports.find({
      measurements: {
        $elemMatch: { code: "FINDING", value: "not detected" }
      }
    }).sort({ report_number: 1 }).toArray());
  // Seed match: P4-LAB-0003.

  // Q6: Capture BEFORE state, then update all completion fields atomically.
  const target = "P4-LAB-0002";
  const before = reports.findOne({ report_number: target });
  print("\n=== Q6: Report BEFORE completion ===");
  printjson(before);
  if (!before) throw new Error("Target report is missing.");

  if (before.status === "pending") {
    const reportedAt = ISODate("2026-10-20T10:00:00Z");
    if (reportedAt < before.requested_at) {
      throw new Error("Demo reporting time precedes the stored request time; inspect the report.");
    }
    // Include the observed request time and empty measurements in the filter.
    // A conflicting edit will produce matchedCount=0 rather than be overwritten.
    const result = reports.updateOne(
      {
        report_number: target,
        status: "pending",
        requested_at: before.requested_at,
        measurements: { $size: 0 },
        reported_at: { $exists: false }
      },
      {
        $set: {
          measurements: [
            { code: "GLU", name: "Demo glucose measurement", value: 5.1, unit: "mmol/L" }
          ],
          status: "completed",
          reported_at: reportedAt
        }
      }
    );
    print("\n=== Q6: Update acknowledgement ===");
    printjson(result);
    if (result.matchedCount !== 1 || result.modifiedCount !== 1) {
      throw new Error("Completion was not applied exactly once. Inspect current report; do not force overwrite.");
    }
  } else if (before.status === "completed") {
    print("Q6 UPDATE SKIPPED: already completed. This rerun does not demonstrate a new transition.");
  } else {
    throw new Error("Expected pending or previously completed target; found " + before.status);
  }

  const after = reports.findOne({ report_number: target });
  if (after.status !== "completed" || !(after.reported_at instanceof Date) ||
      !Array.isArray(after.measurements) || after.measurements.length === 0) {
    throw new Error("Stored completion state failed verification.");
  }
  print("\n=== Q6: Report AFTER completion ===");
  printjson(after);

  // Q7: Re-read work queue to demonstrate the effect of the update.
  output("Q7: Pending P4 reports AFTER update",
    reports.find({ report_number: { $in: batch }, status: "pending" })
      .sort({ requested_at: 1, report_number: 1 }).toArray());
  // Expected after the initial successful update: only P4-LAB-0005.

  // Q8: Actual stored status counts for the five demonstration reports.
  print("\n=== Q8: P4 batch status summary AFTER update ===");
  printjson(reports.aggregate([
    { $match: { report_number: { $in: batch } } },
    { $group: { _id: "$status", count: { $sum: 1 } } },
    { $sort: { _id: 1 } }
  ]).toArray());
  // Expected for an otherwise unchanged seed: completed=3, pending=1, in-progress=1.

  // Q9: Inspect patient-history execution behaviour without forcing an index.
  // On only five documents MongoDB may choose a collection scan; that is valid.
  // Do not claim an index benefit unless the actual plan supports it.
  print("\n=== Q9: Patient-history explain executionStats ===");
  printjson(reports.find({ patient_number: "PAT001" })
    .sort({ requested_at: -1, report_number: 1 }).explain("executionStats"));

  print("\nQUERIES FINISHED. Save actual labelled outputs as Portfolio 4 evidence.");
  print("This script does not verify external PostgreSQL references or clinical validity.");
})();
