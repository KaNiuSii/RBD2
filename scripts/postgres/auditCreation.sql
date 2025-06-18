-- Create audit table
CREATE TABLE remarks.remark_audit (
    audit_id SERIAL PRIMARY KEY,
    remark_id INTEGER,
    operation VARCHAR(10),
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create audit trigger function
CREATE OR REPLACE FUNCTION remarks.audit_remark_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO remarks.remark_audit (remark_id, operation, new_data, changed_by)
        VALUES (NEW.id, 'INSERT', to_jsonb(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO remarks.remark_audit (remark_id, operation, old_data, new_data, changed_by)
        VALUES (NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_user);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO remarks.remark_audit (remark_id, operation, old_data, changed_by)
        VALUES (OLD.id, 'DELETE', to_jsonb(OLD), current_user);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trg_remark_audit
    AFTER INSERT OR UPDATE OR DELETE ON remarks.remark
    FOR EACH ROW EXECUTE FUNCTION remarks.audit_remark_changes();