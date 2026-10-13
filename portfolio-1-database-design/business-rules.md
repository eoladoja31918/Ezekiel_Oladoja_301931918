# Clinic Business Rules

## Patients and Doctors
1. Each patient must have a unique patient number.
2. Each doctor must have a unique doctor number.
3. Patient names, date of birth, doctor names, and identifiers are mandatory.

## Appointments
4. Each appointment belongs to exactly one patient and one doctor.
5. Patients and doctors may have multiple appointments.
6. An appointment's end time must be later than its start time.
7. Scheduled appointments for the same doctor must not overlap.
8. Scheduled appointments for the same patient must not overlap.
9. Appointment status must be scheduled, completed, cancelled, or no-show.

## Diagnoses
10. Each diagnosis belongs to exactly one appointment.
11. An appointment may have zero or multiple diagnoses.
12. Each diagnosis must include a description and recording timestamp.

## Prescriptions
13. Each prescription belongs to exactly one appointment.
14. An appointment may have zero or multiple prescriptions.
15. Each finalised prescription must contain at least one medication item.
16. Each medication item belongs to exactly one prescription.
17. Medication name, dosage, frequency, and duration are mandatory.

## Laboratory Records
18. Each laboratory request belongs to exactly one appointment.
19. An appointment may have zero or multiple laboratory requests.
20. Each submitted laboratory request must contain at least one requested test.
21. Each request item references exactly one test from the laboratory test catalogue.
22. Each catalogue test must have a unique test code.
23. The same catalogue test may appear in multiple request items.
24. A request item may have zero or multiple result measurements.
25. Each result measurement belongs to exactly one request item.
26. Measurement name, result value, and recording timestamp are mandatory.
27. Laboratory request status must be pending, in-progress, completed, or cancelled.
28. Laboratory request item status must be pending, in-progress, completed, or cancelled.

## Data Integrity
29. All foreign keys must reference existing records.
30. Referenced records cannot be deleted while dependent records exist.
31. Patient medical history is retrieved through appointments and their
    associated diagnoses, prescriptions, and laboratory records.

## Implementation Notes
Primary keys, foreign keys, NOT NULL, UNIQUE, and CHECK constraints will
enforce suitable rules directly.

Appointment overlap prevention requires an appropriate database constraint
or scheduling control.

Minimum-item rules for finalised prescriptions and submitted laboratory
requests require transaction logic or database triggers.
