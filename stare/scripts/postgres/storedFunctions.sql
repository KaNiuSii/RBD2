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