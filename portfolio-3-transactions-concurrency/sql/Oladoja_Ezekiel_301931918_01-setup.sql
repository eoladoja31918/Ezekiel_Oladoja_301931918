BEGIN;

INSERT INTO clinic.patients (
    patient_number,
    first_name,
    last_name,
    date_of_birth
)
VALUES
    ('P3-P-01', 'Transaction', 'Patient One', '1990-01-01'),
    ('P3-P-02', 'Transaction', 'Patient Two', '1992-01-01');

INSERT INTO clinic.doctors (
    doctor_number,
    full_name,
    specialisation
)
VALUES (
    'P3-D-01',
    'P3 Demo Doctor',
    'General Medicine'
);

COMMIT;

-- Confirm the test records exist.
SELECT patient_number, first_name, last_name
FROM clinic.patients
WHERE patient_number IN ('P3-P-01', 'P3-P-02');

SELECT doctor_number, full_name
FROM clinic.doctors
WHERE doctor_number = 'P3-D-01';
