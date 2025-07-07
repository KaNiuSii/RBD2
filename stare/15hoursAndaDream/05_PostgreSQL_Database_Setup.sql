
CREATE SCHEMA remarks_main;
CREATE SCHEMA remarks_remote1;
CREATE SCHEMA remarks_remote2;

CREATE USER remarks_user WITH PASSWORD 'Remarks123';
CREATE USER remote1_user WITH PASSWORD 'Remote123';
CREATE USER remote2_user WITH PASSWORD 'Remote123';

GRANT USAGE ON SCHEMA remarks_main TO remarks_user;
GRANT USAGE ON SCHEMA remarks_remote1 TO remote1_user;
GRANT USAGE ON SCHEMA remarks_remote2 TO remote2_user;

GRANT USAGE ON SCHEMA remarks_remote1 TO remarks_user;
GRANT USAGE ON SCHEMA remarks_remote2 TO remarks_user;
GRANT USAGE ON SCHEMA remarks_main TO remote1_user;
GRANT USAGE ON SCHEMA remarks_main TO remote2_user;

CREATE TABLE remarks_main.remark (
    id SERIAL PRIMARY KEY,
    studentId INTEGER NOT NULL,
    teacherId INTEGER NOT NULL,
    value TEXT NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_remark_student ON remarks_main.remark(studentId);
CREATE INDEX idx_remark_teacher ON remarks_main.remark(teacherId);
CREATE INDEX idx_remark_date ON remarks_main.remark(created_date);

CREATE TABLE remarks_remote1.remark_archive (
    id SERIAL PRIMARY KEY,
    studentId INTEGER NOT NULL,
    teacherId INTEGER NOT NULL,
    value TEXT NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    archived_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE remarks_remote2.remark_summary (
    id SERIAL PRIMARY KEY,
    studentId INTEGER NOT NULL,
    teacherId INTEGER NOT NULL,
    remark_count INTEGER NOT NULL,
    last_remark_date TIMESTAMP
);

GRANT SELECT, INSERT, UPDATE, DELETE ON remarks_main.remark TO remarks_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON remarks_remote1.remark_archive TO remote1_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON remarks_remote2.remark_summary TO remote2_user;

GRANT SELECT ON remarks_remote1.remark_archive TO remarks_user;
GRANT SELECT ON remarks_remote2.remark_summary TO remarks_user;
GRANT SELECT ON remarks_main.remark TO remote1_user;
GRANT SELECT ON remarks_main.remark TO remote2_user;

GRANT USAGE, SELECT ON SEQUENCE remarks_main.remark_id_seq TO remarks_user;
GRANT USAGE, SELECT ON SEQUENCE remarks_remote1.remark_archive_id_seq TO remote1_user;
GRANT USAGE, SELECT ON SEQUENCE remarks_remote2.remark_summary_id_seq TO remote2_user;

CREATE VIEW remarks_main.distributed_remarks AS
SELECT 
    r.id,
    r.studentId,
    r.teacherId,
    r.value,
    r.created_date,
    'MAIN' as source_schema
FROM remarks_main.remark r
UNION ALL
SELECT 
    ra.id + 10000 as id,
    ra.studentId,
    ra.teacherId,
    ra.value,
    ra.created_date,
    'REMOTE1' as source_schema
FROM remarks_remote1.remark_archive ra;

CREATE OR REPLACE FUNCTION remarks_main.get_student_remarks(student_id INTEGER)
RETURNS TABLE(
    remark_id INTEGER,
    teacher_id INTEGER,
    remark_text TEXT,
    remark_date TIMESTAMP,
    source TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.teacherId,
        r.value,
        r.created_date,
        'MAIN'::TEXT
    FROM remarks_main.remark r
    WHERE r.studentId = student_id

    UNION ALL

    SELECT 
        ra.id + 10000,
        ra.teacherId,
        ra.value,
        ra.created_date,
        'ARCHIVE'::TEXT
    FROM remarks_remote1.remark_archive ra
    WHERE ra.studentId = student_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remarks_main.simulate_fdw_query(
    remote_schema TEXT,
    table_name TEXT,
    student_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    result_json JSONB
) AS $$
DECLARE
    query_sql TEXT;
BEGIN
    IF remote_schema = 'remarks_remote1' AND table_name = 'remark_archive' THEN
        IF student_id IS NOT NULL THEN
            RETURN QUERY
            SELECT jsonb_build_object(
                'id', ra.id,
                'studentId', ra.studentId,
                'teacherId', ra.teacherId,
                'value', ra.value,
                'created_date', ra.created_date,
                'schema', 'remarks_remote1'
            )
            FROM remarks_remote1.remark_archive ra
            WHERE ra.studentId = simulate_fdw_query.student_id;
        ELSE
            RETURN QUERY
            SELECT jsonb_build_object(
                'id', ra.id,
                'studentId', ra.studentId,
                'teacherId', ra.teacherId,
                'value', ra.value,
                'created_date', ra.created_date,
                'schema', 'remarks_remote1'
            )
            FROM remarks_remote1.remark_archive ra;
        END IF;
    ELSIF remote_schema = 'remarks_remote2' AND table_name = 'remark_summary' THEN
        RETURN QUERY
        SELECT jsonb_build_object(
            'id', rs.id,
            'studentId', rs.studentId,
            'teacherId', rs.teacherId,
            'remark_count', rs.remark_count,
            'last_remark_date', rs.last_remark_date,
            'schema', 'remarks_remote2'
        )
        FROM remarks_remote2.remark_summary rs
        WHERE (student_id IS NULL OR rs.studentId = simulate_fdw_query.student_id);
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW remarks_main.mv_student_remark_stats AS
SELECT 
    studentId,
    COUNT(*) as total_remarks,
    COUNT(DISTINCT teacherId) as teachers_count,
    MIN(created_date) as first_remark_date,
    MAX(created_date) as last_remark_date
FROM remarks_main.remark
GROUP BY studentId;

CREATE INDEX idx_mv_student_remark_stats_student ON remarks_main.mv_student_remark_stats(studentId);

CREATE OR REPLACE FUNCTION remarks_main.update_remark_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO remarks_remote2.remark_summary (studentId, teacherId, remark_count, last_remark_date)
    VALUES (NEW.studentId, NEW.teacherId, 1, NEW.created_date)
    ON CONFLICT (studentId, teacherId) DO UPDATE SET
        remark_count = remarks_remote2.remark_summary.remark_count + 1,
        last_remark_date = NEW.created_date;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE remarks_remote2.remark_summary 
ADD CONSTRAINT uk_student_teacher UNIQUE (studentId, teacherId);

CREATE TRIGGER tr_remark_summary_update
    AFTER INSERT ON remarks_main.remark
    FOR EACH ROW
    EXECUTE FUNCTION remarks_main.update_remark_summary();

