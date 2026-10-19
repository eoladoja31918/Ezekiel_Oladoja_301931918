Initial design: unnormalised
Appointment ID	Patient ID	Patient Name	Doctor ID	Doctor Name	Medications
A001	P001	Amina Bello	D001	Dr Cole	Paracetamol: 500 mg; Amoxicillin: 500 mg
A002	P001	Amina Bello	D002	Dr Musa	Ibuprofen: 400 mg


Problem: The medications field contains multiple medication-and-dosage pairs. Individual medications are difficult to search or update.
1NF: Remove repeating groups
Create one row for each medication line:
Appointment ID	Line No.	Patient ID	Patient Name	Doctor ID	Doctor Name	Medication	Dosage
A001	1	P001	Amina Bello	D001	Dr Cole	Paracetamol	500 mg
A001	2	P001	Amina Bello	D001	Dr Cole	Amoxicillin	500 mg
A002	1	P001	Amina Bello	D002	Dr Musa	Ibuprofen	400 mg


Primary key: (Appointment ID, Line No.)
Each field now contains one value, and each medication line is uniquely identified.
Remaining problem: Patient and doctor details depend only on Appointment ID, rather than the whole composite key. They repeat for every medication line.
2NF: Remove partial dependencies
Separate appointment details from medication lines.
Appointments
Appointment ID — PK	Patient ID	Patient Name	Doctor ID	Doctor Name
A001	P001	Amina Bello	D001	Dr Cole
A002	P001	Amina Bello	D002	Dr Musa


Medication Lines
Appointment ID — PK/FK	Line No. — PK	Medication	Dosage
A001	1	Paracetamol	500 mg
A001	2	Amoxicillin	500 mg
A002	1	Ibuprofen	400 mg


Appointment details are stored once per appointment. Medication and dosage depend on the complete medication-line key.
Remaining problem: Within Appointments, patient names depend on patient IDs, and doctor names depend on doctor IDs:
Appointment ID → Patient ID → Patient Name
Appointment ID → Doctor ID → Doctor Name

These are transitive dependencies.
3NF: Remove transitive dependencies
Move patient and doctor details into their own tables.
Patients
Patient ID — PK	Patient Name
P001	Amina Bello


Doctors
Doctor ID — PK	Doctor Name
D001	Dr Cole
D002	Dr Musa


Appointments
Appointment ID — PK	Patient ID — FK	Doctor ID — FK
A001	P001	D001
A002	P001	D002


Medication Lines
Appointment ID — PK/FK	Line No. — PK	Medication	Dosage
A001	1	Paracetamol	500 mg
A001	2	Amoxicillin	500 mg
A002	1	Ibuprofen	400 mg


Patient and doctor details are now stored independently. Changing Amina’s name requires one update, while her appointments continue to reference the same patient record.
How this maps to your actual clinic schema
Your full design adds prescription headers because one appointment may produce multiple prescriptions:
Patients → Appointments ← Doctors
Appointments → Prescriptions → Prescription Items

Laboratory records follow the same principles: separate the request, its requested tests, the test catalogue, and individual result measurements.
Normal form	Change made
1NF	Store each medication or measurement separately
2NF	Separate header details from individual items
3NF	Store patient, doctor, and test details in their own tables
