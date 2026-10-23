// MIT 8103 Portfolio 5: READ-ONLY Atlas deployment inspection.
// Prerequisite: connect mongosh to the Atlas cluster used for Portfolio 4.
// Run: load("C:/Users/YOUR_NAME/Downloads/01-inspect-deployment.js")
// Creates NO databases, collections, indexes or reports. Does not update data,
// change connection settings, force elections, or test failover.
// Output includes topology hostnames, but deliberately omits connection URIs,
// credentials, user lists and full patient/report documents.

(() => {
  const clinic = db.getSiblingDB("clinic_nosql");
  const admin = db.getSiblingDB("admin");
  const collection = "laboratory_reports";
  const evidence = [];

  // Commands can be unavailable because of account privileges or Atlas tier.
  // Preserve that limitation as evidence instead of escalating permissions.
  function inspect(section, action) {
    const startedAt = new Date();
    try {
      const result = action();
      const row = { section, captured_at: startedAt, status: "OBSERVED", result };
      evidence.push(row);
      print("\n=== " + section + " ===");
      printjson(row);
      return result;
    } catch (error) {
      const row = {
        section, captured_at: startedAt, status: "UNAVAILABLE",
        error_code: error.code === undefined ? null : error.code,
        error_name: error.codeName || error.name || "Error",
        message: String(error.message || error)
      };
      evidence.push(row);
      print("\n=== " + section + ": UNAVAILABLE ===");
      printjson(row);
      return null;
    }
  }

  function command(database, body) {
    const result = database.runCommand(body);
    if (result.ok !== 1) {
      const err = new Error(result.errmsg || "Command was not acknowledged");
      err.code = result.code;
      err.codeName = result.codeName;
      throw err;
    }
    return result;
  }

  print("READ-ONLY DEPLOYMENT INSPECTION: clinic_nosql.laboratory_reports");

  inspect("1. Connection acknowledgement", () => {
    const r = command(clinic, { ping: 1 });
    return { database: clinic.getName(), ok: r.ok };
  });

  inspect("2. Topology advertised by hello", () => {
    const h = command(admin, { hello: 1 });
    const result = {};
    for (const field of [
      "setName", "isWritablePrimary", "secondary", "primary", "me",
      "hosts", "passives", "arbiters", "msg", "localTime", "maxWireVersion"
    ]) {
      if (h[field] !== undefined) result[field] = h[field];
    }
    result.interpretation = h.msg === "isdbgrid"
      ? "Connected endpoint identifies as a mongos router; this does not prove this collection is sharded."
      : h.setName
        ? "Endpoint advertises replica-set membership. Host listing is discovery evidence, not a health or failover test."
        : "No replica-set name was advertised; do not infer replica-set topology from this result alone.";
    if (Array.isArray(h.hosts)) result.advertised_hosts_count = h.hosts.length;
    return result;
  });

  inspect("3. Server version (if permitted)", () => {
    const r = command(admin, { buildInfo: 1 });
    return { version: r.version, versionArray: r.versionArray };
  });

  const details = inspect("4. Collection options and validation", () => {
    const c = clinic.getCollectionInfos({ name: collection });
    if (!c.length) throw new Error("Collection is absent or not visible to this user. Inspect Portfolio 4 setup.");
    return { database: clinic.getName(), name: c[0].name, type: c[0].type, options: c[0].options };
  });

  if (details) {
    inspect("5. Stored index definitions", () => clinic.getCollection(collection).getIndexes());

    inspect("6. Total report count", () => {
      const r = command(clinic, {
        aggregate: collection, pipeline: [{ $count: "reports" }], cursor: {}, maxTimeMS: 15000
      });
      return { reports: r.cursor.firstBatch.length ? r.cursor.firstBatch[0].reports : 0 };
    });

    inspect("7. P4 batch status counts", () => {
      const r = command(clinic, {
        aggregate: collection,
        pipeline: [
          { $match: { report_number: { $in: [
            "P4-LAB-0001", "P4-LAB-0002", "P4-LAB-0003", "P4-LAB-0004", "P4-LAB-0005"
          ] } } },
          { $group: { _id: "$status", reports: { $sum: 1 } } },
          { $sort: { _id: 1 } }
        ], cursor: {}, maxTimeMS: 15000
      });
      return { statuses: r.cursor.firstBatch };
    });

    inspect("8. Explicit majority-read example", () => {
      const r = command(clinic, {
        find: collection,
        filter: { report_number: "P4-LAB-0002" },
        projection: { _id: 0, report_number: 1, status: 1, requested_at: 1, reported_at: 1 },
        limit: 1, singleBatch: true,
        readConcern: { level: "majority" }, maxTimeMS: 15000
      });
      return {
        requested_read_concern: "majority", ok: r.ok,
        reports: r.cursor.firstBatch,
        limitation: "A successful majority read is not proof of latest-write freshness, replication lag, linearizability, or majority write acknowledgement. No writes are issued."
      };
    });
  }

  inspect("9. Database statistics (if permitted)", () => {
    const r = command(clinic, { dbStats: 1, scale: 1024 });
    const result = {};
    for (const field of ["db", "collections", "objects", "dataSize", "storageSize", "indexes", "indexSize", "scaleFactor"]) {
      if (r[field] !== undefined) result[field] = r[field];
    }
    result.note = "Sizes are scaled by the requested factor of 1024 where applicable; counts are not sizes.";
    return result;
  });

  // Optional detailed health may be blocked for Free/Flex tiers or this user.
  // An unavailable result is NOT evidence that replication is absent.
  inspect("10. Replica status (optional; may be restricted)", () => {
    const r = command(admin, { replSetGetStatus: 1 });
    return {
      set: r.set, date: r.date, myState: r.myState,
      members: (r.members || []).map(m => ({
        name: m.name, health: m.health, stateStr: m.stateStr, self: m.self,
        optimeDate: m.optimeDate
      }))
    };
  });

  // Read settings only. This does not set or change read/write concern.
  inspect("11. Default concerns (optional; may be restricted)", () => {
    const r = command(admin, { getDefaultRWConcern: 1 });
    const result = {};
    for (const field of ["defaultReadConcern", "defaultWriteConcern", "defaultReadConcernSource", "defaultWriteConcernSource"]) {
      if (r[field] !== undefined) result[field] = r[field];
    }
    result.note = "Server defaults do not prove the concern used by earlier Portfolio 4 operations; clients can override them.";
    return result;
  });

  const available = evidence.filter(e => e.status === "OBSERVED").length;
  print("\n=== INSPECTION SUMMARY ===");
  printjson({
    captured_at: new Date(), sections_observed: available,
    sections_unavailable: evidence.length - available,
    reports_changed_by_script: false,
    limitations: [
      "No replication-lag measurement, election or outage simulation was performed.",
      "No sharding configuration was changed or collection-sharding claim established.",
      "Cloud provider, region, cluster tier and resilience configuration require Atlas UI evidence.",
      "Unavailable commands indicate a tier/permission limitation, not a failed deployment."
    ]
  });

  // One complete Extended JSON bundle, convenient to copy into an evidence file.
  // Dates/BSON values retain their types in Extended JSON.
  print("\n=== BEGIN DEPLOYMENT EVIDENCE JSON ===");
  print(EJSON.stringify({
    portfolio: 5, database: "clinic_nosql", collection,
    read_only: true, evidence
  }, null, 2));
  print("=== END DEPLOYMENT EVIDENCE JSON ===");
  print("Save output as evidence/deployment-inspection.json or screenshots.");
})();
