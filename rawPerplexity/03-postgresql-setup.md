# PostgreSQL Database Setup Script

## 1. Database and User Creation

```sql
-- Connect as a superuser (postgres)
-- Create database for remarks system
CREATE DATABASE remarks_system;

-- Connect to the new database
\c remarks_system;

-- Create a dedicated user for the remarks system
CREATE USER remarks_admin WITH PASSWORD 'secure_password';

-- Grant necessary privileges
GRANT ALL PRIVILEGES ON DATABASE remarks_system TO remarks_admin;

-- Create schema for better organization
CREATE SCHEMA remarks;
GRANT ALL ON SCHEMA remarks TO remarks_admin;

-- Set default schema for the user
ALTER USER remarks_admin SET search_path TO remarks, public;
```

## 2. Table Creation

```sql
-- Switch to remarks_admin user
SET ROLE remarks_admin;

-- Create the remarks table
CREATE TABLE remarks.remark (
    id SERIAL PRIMARY KEY,
    studentId INTEGER NOT NULL,
    teacherId INTEGER NOT NULL,
    value TEXT NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    severity VARCHAR(20) DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'SERIOUS', 'CRITICAL')),
    category VARCHAR(50) DEFAULT 'GENERAL' CHECK (category IN ('ACADEMIC', 'BEHAVIORAL', 'ATTENDANCE', 'GENERAL'))
);

-- Create indexes for better performance
CREATE INDEX idx_remark_student ON remarks.remark(studentId);
CREATE INDEX idx_remark_teacher ON remarks.remark(teacherId);
CREATE INDEX idx_remark_date ON remarks.remark(created_date);
CREATE INDEX idx_remark_severity ON remarks.remark(severity);
CREATE INDEX idx_remark_category ON remarks.remark(category);
```

## 3. Setup Foreign Data Wrapper for MSSQL Connection

```sql
-- Enable postgres_fdw extension
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- For SQL Server connection, you would typically use tds_fdw or odbc_fdw
-- Since we're connecting to MSSQL, we'll use a different approach
-- Install tds_fdw extension if available, or use dblink for basic connectivity

-- Alternative: Create a foreign data wrapper for ODBC (if available)
-- CREATE EXTENSION IF NOT EXISTS odbc_fdw;

-- For demonstration, we'll create a simple connection using dblink
CREATE EXTENSION IF NOT EXISTS dblink;

-- Create a connection function to MSSQL
CREATE OR REPLACE FUNCTION get_mssql_connection() 
RETURNS TEXT AS $$
BEGIN
    -- Replace with your actual MSSQL connection string
    RETURN 'host=mssql_server_ip port=1433 dbname=SchoolManagement user=mssql_user password=mssql_password';
END;
$$ LANGUAGE plpgsql;
```

## 4. Create Functions for Data Validation

```sql
-- Function to validate if student exists in MSSQL
CREATE OR REPLACE FUNCTION validate_student_exists(student_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    student_count INTEGER;
    conn_str TEXT;
BEGIN
    -- For actual implementation, you would use dblink or FDW
    -- This is a simplified version for demonstration
    
    -- In a real scenario, you would query the remote MSSQL server
    -- For now, we'll assume the student exists if ID is positive
    RETURN student_id > 0;
    
    /*
    -- Real implementation with dblink:
    conn_str := get_mssql_connection();
    
    SELECT INTO student_count (
        SELECT count 
        FROM dblink(conn_str, 'SELECT COUNT(*) as count FROM students WHERE id = ' || student_id) 
        AS remote_data(count INTEGER)
    );
    
    RETURN student_count > 0;
    */
END;
$$ LANGUAGE plpgsql;

-- Function to validate if teacher exists in MSSQL
CREATE OR REPLACE FUNCTION validate_teacher_exists(teacher_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    teacher_count INTEGER;
BEGIN
    -- Similar to student validation
    RETURN teacher_id > 0;
END;
$$ LANGUAGE plpgsql;
```

## 5. Create Stored Functions for Remark Management

```sql
-- Function to add a new remark with validation
CREATE OR REPLACE FUNCTION add_remark(
    p_student_id INTEGER,
    p_teacher_id INTEGER,
    p_value TEXT,
    p_severity VARCHAR(20) DEFAULT 'INFO',
    p_category VARCHAR(50) DEFAULT 'GENERAL'
)
RETURNS INTEGER AS $$
DECLARE
    new_remark_id INTEGER;
BEGIN
    -- Validate inputs
    IF NOT validate_student_exists(p_student_id) THEN
        RAISE EXCEPTION 'Student with ID % does not exist in the main database', p_student_id;
    END IF;
    
    IF NOT validate_teacher_exists(p_teacher_id) THEN
        RAISE EXCEPTION 'Teacher with ID % does not exist in the main database', p_teacher_id;
    END IF;
    
    IF LENGTH(TRIM(p_value)) = 0 THEN
        RAISE EXCEPTION 'Remark value cannot be empty';
    END IF;
    
    -- Insert the remark
    INSERT INTO remarks.remark (studentId, teacherId, value, severity, category)
    VALUES (p_student_id, p_teacher_id, p_value, p_severity, p_category)
    RETURNING id INTO new_remark_id;
    
    RETURN new_remark_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get remarks for a specific student
CREATE OR REPLACE FUNCTION get_student_remarks(p_student_id INTEGER)
RETURNS TABLE(
    remark_id INTEGER,
    student_id INTEGER,
    teacher_id INTEGER,
    remark_text TEXT,
    severity VARCHAR(20),
    category VARCHAR(50),
    created_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.studentId,
        r.teacherId,
        r.value,
        r.severity,
        r.category,
        r.created_date
    FROM remarks.remark r
    WHERE r.studentId = p_student_id
    ORDER BY r.created_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get remarks by teacher
CREATE OR REPLACE FUNCTION get_teacher_remarks(p_teacher_id INTEGER)
RETURNS TABLE(
    remark_id INTEGER,
    student_id INTEGER,
    teacher_id INTEGER,
    remark_text TEXT,
    severity VARCHAR(20),
    category VARCHAR(50),
    created_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.studentId,
        r.teacherId,
        r.value,
        r.severity,
        r.category,
        r.created_date
    FROM remarks.remark r
    WHERE r.teacherId = p_teacher_id
    ORDER BY r.created_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get summary statistics
CREATE OR REPLACE FUNCTION get_remarks_summary()
RETURNS TABLE(
    total_remarks BIGINT,
    remarks_by_severity JSONB,
    remarks_by_category JSONB,
    recent_remarks_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM remarks.remark) as total_remarks,
        (SELECT json_object_agg(severity, count) FROM (
            SELECT severity, COUNT(*) as count 
            FROM remarks.remark 
            GROUP BY severity
        ) s) as remarks_by_severity,
        (SELECT json_object_agg(category, count) FROM (
            SELECT category, COUNT(*) as count 
            FROM remarks.remark 
            GROUP BY category
        ) c) as remarks_by_category,
        (SELECT COUNT(*) FROM remarks.remark 
         WHERE created_date >= CURRENT_DATE - INTERVAL '7 days') as recent_remarks_count;
END;
$$ LANGUAGE plpgsql;
```

## 6. Create Views for Easier Data Access

```sql
-- Create a view for recent remarks (last 30 days)
CREATE VIEW remarks.vw_recent_remarks AS
SELECT 
    r.id,
    r.studentId,
    r.teacherId,
    r.value,
    r.severity,
    r.category,
    r.created_date,
    CASE 
        WHEN r.created_date >= CURRENT_DATE - INTERVAL '1 day' THEN 'Today'
        WHEN r.created_date >= CURRENT_DATE - INTERVAL '7 days' THEN 'This Week'
        WHEN r.created_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'This Month'
        ELSE 'Older'
    END as time_period
FROM remarks.remark r
WHERE r.created_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY r.created_date DESC;

-- Create a view for serious remarks
CREATE VIEW remarks.vw_serious_remarks AS
SELECT 
    r.id,
    r.studentId,
    r.teacherId,
    r.value,
    r.severity,
    r.category,
    r.created_date
FROM remarks.remark r
WHERE r.severity IN ('SERIOUS', 'CRITICAL')
ORDER BY r.created_date DESC;

-- Create a materialized view for performance (refreshed periodically)
CREATE MATERIALIZED VIEW remarks.mv_remarks_statistics AS
SELECT 
    DATE_TRUNC('day', created_date) as remark_date,
    COUNT(*) as total_remarks,
    COUNT(*) FILTER (WHERE severity = 'CRITICAL') as critical_remarks,
    COUNT(*) FILTER (WHERE severity = 'SERIOUS') as serious_remarks,
    COUNT(*) FILTER (WHERE severity = 'WARNING') as warning_remarks,
    COUNT(*) FILTER (WHERE severity = 'INFO') as info_remarks,
    COUNT(DISTINCT studentId) as unique_students,
    COUNT(DISTINCT teacherId) as unique_teachers
FROM remarks.remark
GROUP BY DATE_TRUNC('day', created_date)
ORDER BY remark_date DESC;

-- Create index on materialized view
CREATE INDEX idx_mv_remarks_stats_date ON remarks.mv_remarks_statistics(remark_date);
```

## 7. Insert Sample Data

```sql
-- Generate sample remarks data
DO $$
DECLARE
    i INTEGER;
    student_ids INTEGER[] := ARRAY[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20];
    teacher_ids INTEGER[] := ARRAY[1,2,3,4,5,6,7,8,9,10];
    severities VARCHAR(20)[] := ARRAY['INFO', 'WARNING', 'SERIOUS', 'CRITICAL'];
    categories VARCHAR(50)[] := ARRAY['ACADEMIC', 'BEHAVIORAL', 'ATTENDANCE', 'GENERAL'];
    sample_remarks TEXT[] := ARRAY[
        'Excellent participation in class discussion',
        'Late to class multiple times this week',
        'Outstanding performance on recent assignment',
        'Disruptive behavior during lesson',
        'Improved significantly in mathematics',
        'Absent without valid excuse',
        'Helpful to other students during group work',
        'Incomplete homework submissions',
        'Demonstrated leadership skills',
        'Needs additional support in reading',
        'Consistently punctual and prepared',
        'Inappropriate language used in class',
        'Creative thinking in problem solving',
        'Difficulty focusing during lessons',
        'Positive attitude and enthusiasm'
    ];
    random_student INTEGER;
    random_teacher INTEGER;
    random_severity VARCHAR(20);
    random_category VARCHAR(50);
    random_remark TEXT;
    random_days INTEGER;
BEGIN
    -- Generate 100 sample remarks
    FOR i IN 1..100 LOOP
        -- Select random values
        random_student := student_ids[1 + (random() * (array_length(student_ids, 1) - 1))::INTEGER];
        random_teacher := teacher_ids[1 + (random() * (array_length(teacher_ids, 1) - 1))::INTEGER];
        random_severity := severities[1 + (random() * (array_length(severities, 1) - 1))::INTEGER];
        random_category := categories[1 + (random() * (array_length(categories, 1) - 1))::INTEGER];
        random_remark := sample_remarks[1 + (random() * (array_length(sample_remarks, 1) - 1))::INTEGER];
        random_days := (random() * 60)::INTEGER; -- Random date within last 60 days
        
        -- Insert remark
        INSERT INTO remarks.remark (
            studentId, 
            teacherId, 
            value, 
            severity, 
            category, 
            created_date
        ) VALUES (
            random_student,
            random_teacher,
            random_remark,
            random_severity,
            random_category,
            CURRENT_TIMESTAMP - (random_days || ' days')::INTERVAL
        );
    END LOOP;
    
    RAISE NOTICE 'Inserted % sample remarks', i-1;
END $$;

-- Refresh the materialized view
REFRESH MATERIALIZED VIEW remarks.mv_remarks_statistics;
```

## 8. Create Database Roles and Permissions

```sql
-- Create roles for different access levels
CREATE ROLE remarks_readonly;
CREATE ROLE remarks_teacher;
CREATE ROLE remarks_admin;

-- Grant permissions to readonly role
GRANT USAGE ON SCHEMA remarks TO remarks_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA remarks TO remarks_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA remarks TO remarks_readonly;

-- Grant permissions to teacher role
GRANT remarks_readonly TO remarks_teacher;
GRANT INSERT ON remarks.remark TO remarks_teacher;
GRANT EXECUTE ON FUNCTION add_remark(INTEGER, INTEGER, TEXT, VARCHAR, VARCHAR) TO remarks_teacher;
GRANT EXECUTE ON FUNCTION get_student_remarks(INTEGER) TO remarks_teacher;
GRANT EXECUTE ON FUNCTION get_teacher_remarks(INTEGER) TO remarks_teacher;

-- Grant permissions to admin role
GRANT remarks_teacher TO remarks_admin;
GRANT ALL ON ALL TABLES IN SCHEMA remarks TO remarks_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA remarks TO remarks_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA remarks TO remarks_admin;

-- Create sample users
CREATE USER teacher_user WITH PASSWORD 'teacher_password';
GRANT remarks_teacher TO teacher_user;

CREATE USER admin_user WITH PASSWORD 'admin_password';
GRANT remarks_admin TO admin_user;
```

## 9. Create Triggers for Audit Trail

```sql
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
```

## 10. Setup Automated Tasks

```sql
-- Create a function to automatically refresh materialized views
CREATE OR REPLACE FUNCTION refresh_remarks_statistics()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW remarks.mv_remarks_statistics;
    RAISE NOTICE 'Remarks statistics refreshed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- You can set up a cron job or use pg_cron extension to run this periodically
-- Example: SELECT cron.schedule('refresh-remarks-stats', '0 1 * * *', 'SELECT refresh_remarks_statistics();');
```

## 11. Verification and Status Check

```sql
-- Check table creation and data
SELECT 'PostgreSQL Remarks Database Setup Complete!' as status;

SELECT 
    'Tables created: ' || COUNT(*)
FROM information_schema.tables 
WHERE table_schema = 'remarks';

SELECT 
    'Remarks inserted: ' || COUNT(*)
FROM remarks.remark;

SELECT 
    'Functions created: ' || COUNT(*)
FROM information_schema.routines 
WHERE routine_schema = 'remarks';

-- Test functions
SELECT 'Testing remark functions:' as test_section;
SELECT * FROM get_remarks_summary();
```

---

**Next Steps:**
1. Install required extensions (postgres_fdw, dblink, or tds_fdw)
2. Configure actual connection to your MSSQL server
3. Run the script as a PostgreSQL superuser
4. Verify the sample data generation was successful
5. Test the functions and views
6. Configure periodic refresh of materialized views
7. Proceed with the replication setup script