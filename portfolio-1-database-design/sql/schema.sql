-- MIT 8103 Portfolio 1: Hospital / Clinic Management System
-- PostgreSQL 14+; run once in a new database using pgAdmin Query Tool or:
-- psql -U postgres -d clinic_db -v ON_ERROR_STOP=1 -f schema.sql
-- No existing tables are dropped. A second run fails rather than overwriting work.
-- btree_gist must be available; extension creation may require administrator help.
-- All timestamps are stored as timestamptz; this session displays Africa/Lagos time.
-- This implements schema/keys/constraints, not the separate ERD or 3NF explanation.

-- Start a transaction: build the whole schema together.
BEGIN;
-- Enables equality comparisons in the appointment overlap constraints.
CREATE EXTENSION IF NOT EXISTS btree_gist;
-- Keep all clinic tables and functions in their own namespace.
CREATE SCHEMA clinic;
SET LOCAL search_path = clinic, public;
SET LOCAL TIME ZONE 'Africa/Lagos';

-- Stores patient identity and contact details. Patient numbers are unique.
CREATE TABLE patients (
    patient_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_number VARCHAR(30) NOT NULL UNIQUE CHECK (btrim(patient_number) <> ''),
    first_name VARCHAR(100) NOT NULL CHECK (btrim(first_name) <> ''),
    last_name VARCHAR(100) NOT NULL CHECK (btrim(last_name) <> ''),
    date_of_birth DATE NOT NULL,
    phone VARCHAR(30),
    address TEXT
);

-- Stores doctor details and their area of specialisation.
CREATE TABLE doctors (
    doctor_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doctor_number VARCHAR(30) NOT NULL UNIQUE CHECK (btrim(doctor_number) <> ''),
    full_name VARCHAR(200) NOT NULL CHECK (btrim(full_name) <> ''),
    specialisation VARCHAR(150) NOT NULL CHECK (btrim(specialisation) <> '')
);

-- Connects one patient to one doctor for a consultation.
-- Time checks prevent invalid durations; exclusion constraints prevent double booking.
CREATE TABLE appointments (
    appointment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id BIGINT NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    doctor_id BIGINT NOT NULL REFERENCES doctors(doctor_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    CONSTRAINT appointment_times_valid CHECK (end_time > start_time),
    CONSTRAINT appointment_status_valid CHECK (status IN ('scheduled','completed','cancelled','no-show')),
    CONSTRAINT doctor_schedule_no_overlap EXCLUDE USING gist (
        doctor_id WITH =, tstzrange(start_time,end_time,'[)') WITH &&
    ) WHERE (status = 'scheduled'),
    CONSTRAINT patient_schedule_no_overlap EXCLUDE USING gist (
        patient_id WITH =, tstzrange(start_time,end_time,'[)') WITH &&
    ) WHERE (status = 'scheduled')
);

-- Stores diagnoses recorded during an appointment.
CREATE TABLE diagnoses (
    diagnosis_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id BIGINT NOT NULL REFERENCES appointments(appointment_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    diagnosis_description TEXT NOT NULL CHECK (btrim(diagnosis_description) <> ''),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Stores prescription headers. Draft prescriptions can be prepared before issuing.
CREATE TABLE prescriptions (
    prescription_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id BIGINT NOT NULL REFERENCES appointments(appointment_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    issued_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    CONSTRAINT prescription_status_valid CHECK (status IN ('draft','finalised','cancelled')),
    CONSTRAINT finalised_prescription_has_date CHECK (status <> 'finalised' OR issued_at IS NOT NULL)
);

-- Stores individual medications and their usage instructions.
CREATE TABLE prescription_items (
    prescription_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    prescription_id BIGINT NOT NULL REFERENCES prescriptions(prescription_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    medication_name VARCHAR(200) NOT NULL CHECK (btrim(medication_name) <> ''),
    dosage VARCHAR(100) NOT NULL CHECK (btrim(dosage) <> ''),
    frequency VARCHAR(100) NOT NULL CHECK (btrim(frequency) <> ''),
    duration VARCHAR(100) NOT NULL CHECK (btrim(duration) <> '')
);

-- Stores laboratory request headers associated with appointments.
CREATE TABLE laboratory_requests (
    request_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id BIGINT NOT NULL REFERENCES appointments(appointment_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    CONSTRAINT lab_request_status_valid CHECK (status IN ('draft','pending','in-progress','completed','cancelled'))
);

-- Stores the catalogue of available laboratory tests.
CREATE TABLE laboratory_tests (
    test_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_code VARCHAR(30) NOT NULL UNIQUE CHECK (btrim(test_code) <> ''),
    test_name VARCHAR(200) NOT NULL CHECK (btrim(test_name) <> ''),
    description TEXT
);

-- Connects each laboratory request to the tests being requested.
CREATE TABLE laboratory_request_items (
    request_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    request_id BIGINT NOT NULL REFERENCES laboratory_requests(request_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    test_id BIGINT NOT NULL REFERENCES laboratory_tests(test_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT lab_item_status_valid CHECK (status IN ('pending','in-progress','completed','cancelled'))
);

-- Stores individual measurements or findings for a requested test.
CREATE TABLE laboratory_results (
    result_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    request_item_id BIGINT NOT NULL REFERENCES laboratory_request_items(request_item_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    measurement_name VARCHAR(150) NOT NULL CHECK (btrim(measurement_name) <> ''),
    result_value TEXT NOT NULL CHECK (btrim(result_value) <> ''),
    unit VARCHAR(50),
    reference_range VARCHAR(150),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Supporting foreign-key indexes; primary/unique keys already have indexes.
CREATE INDEX appointments_patient_idx ON appointments(patient_id);
CREATE INDEX appointments_doctor_idx ON appointments(doctor_id);
CREATE INDEX diagnoses_appointment_idx ON diagnoses(appointment_id);
CREATE INDEX prescriptions_appointment_idx ON prescriptions(appointment_id);
CREATE INDEX prescription_items_parent_idx ON prescription_items(prescription_id);
CREATE INDEX laboratory_requests_appointment_idx ON laboratory_requests(appointment_id);
CREATE INDEX laboratory_request_items_parent_idx ON laboratory_request_items(request_id);
CREATE INDEX laboratory_request_items_test_idx ON laboratory_request_items(test_id);
CREATE INDEX laboratory_results_item_idx ON laboratory_results(request_item_id);

-- Validate against Lagos calendar date at write time, rather than using a
-- time-dependent CHECK expression whose truth changes as the clock advances.
CREATE FUNCTION validate_birth_date() RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = pg_catalog, clinic AS $$
BEGIN
    IF NOT isfinite(NEW.date_of_birth)
       OR NEW.date_of_birth > (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Lagos')::date THEN
        RAISE EXCEPTION 'Date of birth must be finite and not in the future'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER patients_birth_date_valid
BEFORE INSERT OR UPDATE ON patients
FOR EACH ROW EXECUTE FUNCTION validate_birth_date();

-- Minimum-item rules are checked at transaction end. Create the header and
-- its items in one transaction, then finalise/submit the header before COMMIT.
-- Parent row locks serialize item edits with status changes. READ COMMITTED
-- (PostgreSQL default) and SERIALIZABLE are supported for these four tables.
-- REPEATABLE READ is rejected because an old snapshot could hide child changes.
-- Check that the transaction uses a supported isolation level.
CREATE FUNCTION guard_parent_write() RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = pg_catalog, clinic AS $$
BEGIN
    IF current_setting('transaction_isolation') NOT IN ('read committed','serializable') THEN
        RAISE EXCEPTION 'Use READ COMMITTED or SERIALIZABLE for prescription/lab request writes'
            USING ERRCODE = '0A000';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

-- Lock the related header before changing its items, including moves between headers.
CREATE FUNCTION lock_item_parents() RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = pg_catalog, clinic AS $$
DECLARE
    old_id BIGINT;
    new_id BIGINT;
    parent_id BIGINT;
BEGIN
    IF current_setting('transaction_isolation') NOT IN ('read committed','serializable') THEN
        RAISE EXCEPTION 'Use READ COMMITTED or SERIALIZABLE for prescription/lab item writes'
            USING ERRCODE = '0A000';
    END IF;
    IF TG_OP <> 'INSERT' THEN old_id := (to_jsonb(OLD)->>TG_ARGV[1])::bigint; END IF;
    IF TG_OP <> 'DELETE' THEN new_id := (to_jsonb(NEW)->>TG_ARGV[1])::bigint; END IF;
    FOR parent_id IN SELECT DISTINCT x FROM unnest(ARRAY[old_id,new_id]) x WHERE x IS NOT NULL ORDER BY x LOOP
        EXECUTE format('SELECT 1 FROM clinic.%I WHERE %I = $1 FOR UPDATE',TG_ARGV[0],TG_ARGV[1]) USING parent_id;
    END LOOP;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

-- Arguments: parent table, parent ID/FK column, child table, required statuses.
-- The same ID name is used on the header and its child rows.
-- Reject a finalised/submitted header if it has no items at transaction end.
CREATE FUNCTION enforce_minimum_items() RETURNS TRIGGER LANGUAGE plpgsql
SET search_path = pg_catalog, clinic AS $$
DECLARE
    old_id BIGINT;
    new_id BIGINT;
    parent_id BIGINT;
    current_status TEXT;
    has_items BOOLEAN;
BEGIN
    IF TG_OP <> 'INSERT' THEN old_id := (to_jsonb(OLD)->>TG_ARGV[1])::bigint; END IF;
    IF TG_OP <> 'DELETE' THEN new_id := (to_jsonb(NEW)->>TG_ARGV[1])::bigint; END IF;
    FOR parent_id IN SELECT DISTINCT x FROM unnest(ARRAY[old_id,new_id]) x WHERE x IS NOT NULL LOOP
        current_status := NULL;
        EXECUTE format('SELECT status FROM clinic.%I WHERE %I = $1',TG_ARGV[0],TG_ARGV[1]) INTO current_status USING parent_id;
        IF current_status = ANY(string_to_array(TG_ARGV[3],',')) THEN
            EXECUTE format('SELECT EXISTS (SELECT 1 FROM clinic.%I WHERE %I = $1)',TG_ARGV[2],TG_ARGV[1]) INTO has_items USING parent_id;
            IF NOT has_items THEN
                RAISE EXCEPTION '% % with status % requires at least one item',TG_ARGV[0],parent_id,current_status
                    USING ERRCODE = '23514';
            END IF;
        END IF;
    END LOOP;
    RETURN NULL;
END;
$$;

-- Attach write guards and parent-lock functions to the relevant tables.
CREATE TRIGGER prescriptions_write_guard BEFORE INSERT OR UPDATE OR DELETE ON prescriptions
FOR EACH ROW EXECUTE FUNCTION guard_parent_write();
CREATE TRIGGER laboratory_requests_write_guard BEFORE INSERT OR UPDATE OR DELETE ON laboratory_requests
FOR EACH ROW EXECUTE FUNCTION guard_parent_write();
CREATE TRIGGER prescription_items_parent_lock BEFORE INSERT OR UPDATE OR DELETE ON prescription_items
FOR EACH ROW EXECUTE FUNCTION lock_item_parents('prescriptions','prescription_id');
CREATE TRIGGER laboratory_items_parent_lock BEFORE INSERT OR UPDATE OR DELETE ON laboratory_request_items
FOR EACH ROW EXECUTE FUNCTION lock_item_parents('laboratory_requests','request_id');

-- Deferred triggers allow a header and its items to be saved in one transaction.
CREATE CONSTRAINT TRIGGER prescriptions_minimum_items
AFTER INSERT OR UPDATE OR DELETE ON prescriptions DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION enforce_minimum_items('prescriptions','prescription_id','prescription_items','finalised');
CREATE CONSTRAINT TRIGGER prescription_items_minimum_items
AFTER INSERT OR UPDATE OR DELETE ON prescription_items DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION enforce_minimum_items('prescriptions','prescription_id','prescription_items','finalised');
CREATE CONSTRAINT TRIGGER laboratory_requests_minimum_items
AFTER INSERT OR UPDATE OR DELETE ON laboratory_requests DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION enforce_minimum_items('laboratory_requests','request_id','laboratory_request_items','pending,in-progress,completed');
CREATE CONSTRAINT TRIGGER laboratory_items_minimum_items
AFTER INSERT OR UPDATE OR DELETE ON laboratory_request_items DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION enforce_minimum_items('laboratory_requests','request_id','laboratory_request_items','pending,in-progress,completed');

-- Store brief explanations inside the database for future reference.
COMMENT ON SCHEMA clinic IS 'MIT 8103: simulated clinic; synthetic data only.';
COMMENT ON COLUMN laboratory_results.result_value IS 'Text supports quantitative and qualitative results; numeric analytics need additional typed fields.';
COMMENT ON COLUMN prescriptions.status IS 'Draft allows creation before items; finalised requires issued_at and at least one item.';
COMMENT ON COLUMN laboratory_requests.status IS 'Draft allows creation before items; submitted states require at least one item.';
-- Save all schema changes if every statement succeeded.
COMMIT;

-- Verification: expect ten rows, one per base table.
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'clinic' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Use clinic-qualified names in later scripts, e.g. SELECT * FROM clinic.patients;
-- Keep the ERD aligned: prescriptions.status and laboratory_requests draft state.
-- Finalisation/item changes must use transactions; retry serialization failures
-- or deadlocks if concurrent sessions are used. No sample patient data is inserted.
