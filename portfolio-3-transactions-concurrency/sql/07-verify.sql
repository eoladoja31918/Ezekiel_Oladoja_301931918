-- Run after both race sessions have finished their transactions.
-- Expected booking race: exactly one row, P3-P-01, 09:00-09:30 WAT.
SELECT p.patient_number,d.doctor_number,a.appointment_id,
       a.start_time AT TIME ZONE 'Africa/Lagos' AS start_time_wat,
       a.end_time AT TIME ZONE 'Africa/Lagos' AS end_time_wat,a.status
FROM clinic.appointments a
JOIN clinic.patients p USING(patient_id)
JOIN clinic.doctors d USING(doctor_id)
WHERE d.doctor_number='P3-D-01'
  AND a.start_time >= '2035-02-01 00:00+01'::timestamptz
  AND a.start_time < '2035-02-02 00:00+01'::timestamptz
ORDER BY a.start_time;
