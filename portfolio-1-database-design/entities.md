# Clinic Entities

| Entity | Key attributes |
|---|---|
| Patients | patient_id, patient_number, first_name, last_name, date_of_birth, phone, address |
| Doctors | doctor_id, doctor_number, full_name, specialisation |
| Appointments | appointment_id, patient_id, doctor_id, start_time, end_time, status |
| Diagnoses | diagnosis_id, appointment_id, diagnosis_description, recorded_at |
| Prescriptions | prescription_id, appointment_id, issued_at |
| Prescription Items | prescription_item_id, prescription_id, medication_name, dosage, frequency, duration |
| Laboratory Requests | request_id, appointment_id, requested_at, status |
| Laboratory Tests | test_id, test_code, test_name, description |
| Laboratory Request Items | request_item_id, request_id, test_id, status |
| Laboratory Results | result_id, request_item_id, measurement_name, result_value, unit, reference_range, recorded_at |

Each entity's `_id` field is its primary key.
Fields referencing another entity are foreign keys.
