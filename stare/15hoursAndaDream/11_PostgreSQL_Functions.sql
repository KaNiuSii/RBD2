SET search_path TO remarks_main, remarks_remote1, remarks_remote2, public;

-- ==========================================
-- PostgreSQL Functions
-- ==========================================

-- Function to get student remarks with pagination
CREATE OR REPLACE FUNCTION remarks_main.fn_get_student_remarks_paginated(
    p_student_id INTEGER,
    p_page_size INTEGER DEFAULT 10,
    p_page_number INTEGER DEFAULT 1
)
RETURNS TABLE(
    remark_id INTEGER,
    teacher_id INTEGER,
    remark_text TEXT,
    created_date TIMESTAMP,
    row_number BIGINT,
    total_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH remark_data AS (
        SELECT 
            r.id,
            r.teacherId,
            r.value,
            r.created_date,
            ROW_NUMBER() OVER (ORDER BY r.created_date DESC) as rn,
            COUNT(*) OVER () as total_cnt
        FROM remarks_main.remark r
        WHERE r.studentId = p_student_id
    )
    SELECT 
        rd.id,
        rd.teacherId,
        rd.value,
        rd.created_date,
        rd.rn,
        rd.total_cnt
    FROM remark_data rd
    WHERE rd.rn BETWEEN ((p_page_number - 1) * p_page_size + 1) AND (p_page_number * p_page_size)
    ORDER BY rd.created_date DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remarks_main.fn_distributed_remark_search(
    p_search_text TEXT,
    p_include_archived BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    remark_id INTEGER,
    student_id INTEGER,
    teacher_id INTEGER,
    remark_text TEXT,
    created_date TIMESTAMP,
    source_schema TEXT
) AS $$
BEGIN
    -- Search in main schema
    RETURN QUERY
    SELECT 
        r.id,
        r.studentId,
        r.teacherId,
        r.value,
        r.created_date,
        'MAIN'::TEXT
    FROM remarks_main.remark r
    WHERE r.value ILIKE '%' || p_search_text || '%';

    -- Include archived data if requested
    IF p_include_archived THEN
        RETURN QUERY
        SELECT 
            ra.id + 10000,
            ra.studentId,
            ra.teacherId,
            ra.value,
            ra.created_date,
            'ARCHIVE'::TEXT
        FROM remarks_remote1.remark_archive ra
        WHERE ra.value ILIKE '%' || p_search_text || '%';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to aggregate data across multiple schemas
CREATE OR REPLACE FUNCTION remarks_main.fn_cross_schema_remark_stats(
    p_student_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    schema_name TEXT,
    total_remarks BIGINT,
    unique_teachers BIGINT,
    earliest_remark TIMESTAMP,
    latest_remark TIMESTAMP,
    avg_remark_length NUMERIC
) AS $$
BEGIN
    -- Stats from main schema
    RETURN QUERY
    SELECT 
        'MAIN'::TEXT,
        COUNT(*)::BIGINT,
        COUNT(DISTINCT r.teacherId)::BIGINT,
        MIN(r.created_date),
        MAX(r.created_date),
        AVG(LENGTH(r.value))::NUMERIC
    FROM remarks_main.remark r
    WHERE (p_student_id IS NULL OR r.studentId = p_student_id);

    -- Stats from archive schema
    RETURN QUERY
    SELECT 
        'ARCHIVE'::TEXT,
        COUNT(*)::BIGINT,
        COUNT(DISTINCT ra.teacherId)::BIGINT,
        MIN(ra.created_date),
        MAX(ra.created_date),
        AVG(LENGTH(ra.value))::NUMERIC
    FROM remarks_remote1.remark_archive ra
    WHERE (p_student_id IS NULL OR ra.studentId = p_student_id);

    -- Stats from summary schema
    RETURN QUERY
    SELECT 
        'SUMMARY'::TEXT,
        SUM(rs.remark_count)::BIGINT,
        COUNT(DISTINCT rs.teacherId)::BIGINT,
        MIN(rs.last_remark_date),
        MAX(rs.last_remark_date),
        AVG(rs.remark_count)::NUMERIC
    FROM remarks_remote2.remark_summary rs
    WHERE (p_student_id IS NULL OR rs.studentId = p_student_id);
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Advanced Cross-Schema Operations
-- ==========================================

-- Function to simulate distributed insert operation
CREATE OR REPLACE FUNCTION remarks_main.fn_distributed_insert_remark(
    p_student_id INTEGER,
    p_teacher_id INTEGER,
    p_remark_text TEXT,
    p_auto_archive BOOLEAN DEFAULT FALSE
)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
    v_new_id INTEGER;
    v_archive_id INTEGER;
BEGIN
    -- Insert into main schema
    INSERT INTO remarks_main.remark (studentId, teacherId, value)
    VALUES (p_student_id, p_teacher_id, p_remark_text)
    RETURNING id INTO v_new_id;

    -- Optionally archive immediately
    IF p_auto_archive THEN
        INSERT INTO remarks_remote1.remark_archive (studentId, teacherId, value, created_date)
        VALUES (p_student_id, p_teacher_id, p_remark_text, CURRENT_TIMESTAMP)
        RETURNING id INTO v_archive_id;
    END IF;

    -- Update summary table
    INSERT INTO remarks_remote2.remark_summary (studentId, teacherId, remark_count, last_remark_date)
    VALUES (p_student_id, p_teacher_id, 1, CURRENT_TIMESTAMP)
    ON CONFLICT (studentId, teacherId) DO UPDATE SET
        remark_count = remarks_remote2.remark_summary.remark_count + 1,
        last_remark_date = CURRENT_TIMESTAMP;

    -- Build result JSON
    v_result := json_build_object(
        'success', true,
        'main_id', v_new_id,
        'archive_id', COALESCE(v_archive_id, null),
        'auto_archived', p_auto_archive,
        'timestamp', CURRENT_TIMESTAMP
    );

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'timestamp', CURRENT_TIMESTAMP
        );
END;
$$ LANGUAGE plpgsql;

-- Function to simulate cross-schema data migration
CREATE OR REPLACE FUNCTION remarks_main.fn_migrate_old_remarks(
    p_cutoff_date DATE DEFAULT CURRENT_DATE - INTERVAL '1 year'
)
RETURNS JSON AS $$
DECLARE
    v_migrated_count INTEGER := 0;
    v_result JSON;
    r RECORD;
BEGIN
    -- Move old remarks to archive
    FOR r IN 
        SELECT * FROM remarks_main.remark 
        WHERE created_date < p_cutoff_date
    LOOP
        -- Insert into archive
        INSERT INTO remarks_remote1.remark_archive 
            (studentId, teacherId, value, created_date, archived_date)
        VALUES 
            (r.studentId, r.teacherId, r.value, r.created_date, CURRENT_TIMESTAMP);

        -- Delete from main table
        DELETE FROM remarks_main.remark WHERE id = r.id;

        v_migrated_count := v_migrated_count + 1;
    END LOOP;

    -- Refresh materialized view
    REFRESH MATERIALIZED VIEW remarks_main.mv_student_remark_stats;

    v_result := json_build_object(
        'success', true,
        'migrated_count', v_migrated_count,
        'cutoff_date', p_cutoff_date,
        'migration_date', CURRENT_TIMESTAMP
    );

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'migration_date', CURRENT_TIMESTAMP
        );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Simulated Foreign Data Wrapper Functions
-- ==========================================

-- Function to simulate connecting to external MSSQL data
CREATE OR REPLACE FUNCTION remarks_main.fn_simulate_mssql_student_data(
    p_student_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    student_id INTEGER,
    student_name TEXT,
    birthday DATE,
    group_id INTEGER,
    external_source TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.name,
        s.birth_date,
        s.group_id,
        'MSSQL_SIMULATION'::TEXT
    FROM (
        VALUES 
        (1, 'Emma Anderson', '2005-03-15'::DATE, 1),
        (2, 'Liam Johnson', '2005-07-22'::DATE, 1),
        (3, 'Olivia Williams', '2005-09-10'::DATE, 1),
        (4, 'Noah Brown', '2006-01-05'::DATE, 2),
        (5, 'Ava Jones', '2006-04-18'::DATE, 2)
    ) AS s(id, name, birth_date, group_id)
    WHERE (p_student_id IS NULL OR s.id = p_student_id);
END;
$$ LANGUAGE plpgsql;

-- Function to simulate connecting to Oracle financial data
CREATE OR REPLACE FUNCTION remarks_main.fn_simulate_oracle_finance_data(
    p_student_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    student_id INTEGER,
    monthly_amount NUMERIC,
    total_paid NUMERIC,
    payment_status TEXT,
    external_source TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        f.student_id,
        f.monthly_amount,
        f.total_paid,
        f.payment_status,
        'ORACLE_SIMULATION'::TEXT
    FROM (
        VALUES 
        (1, 500.00, 1500.00, 'CURRENT'),
        (2, 550.00, 1100.00, 'CURRENT'),
        (3, 500.00, 1000.00, 'CURRENT'),
        (4, 600.00, 600.00, 'CURRENT'),
        (5, 525.00, 525.00, 'CURRENT')
    ) AS f(student_id, monthly_amount, total_paid, payment_status)
    WHERE (p_student_id IS NULL OR f.student_id = p_student_id);
END;
$$ LANGUAGE plpgsql;

-- Function to create unified view of student data from all sources
CREATE OR REPLACE FUNCTION remarks_main.fn_unified_student_view(
    p_student_id INTEGER
)
RETURNS JSON AS $$
DECLARE
    v_student_data JSON;
    v_finance_data JSON;
    v_remark_stats JSON;
    v_unified_data JSON;
BEGIN
    -- Get student basic data (simulated MSSQL)
    SELECT json_agg(json_build_object(
        'student_id', student_id,
        'student_name', student_name,
        'birthday', birthday,
        'group_id', group_id
    )) INTO v_student_data
    FROM remarks_main.fn_simulate_mssql_student_data(p_student_id);

    -- Get finance data (simulated Oracle)
    SELECT json_agg(json_build_object(
        'monthly_amount', monthly_amount,
        'total_paid', total_paid,
        'payment_status', payment_status
    )) INTO v_finance_data
    FROM remarks_main.fn_simulate_oracle_finance_data(p_student_id);

    -- Get remark statistics (local PostgreSQL)
    SELECT json_agg(json_build_object(
        'schema_name', schema_name,
        'total_remarks', total_remarks,
        'unique_teachers', unique_teachers,
        'latest_remark', latest_remark
    )) INTO v_remark_stats
    FROM remarks_main.fn_cross_schema_remark_stats(p_student_id);

    -- Combine all data
    v_unified_data := json_build_object(
        'student_info', v_student_data,
        'financial_info', v_finance_data,
        'remark_statistics', v_remark_stats,
        'generated_at', CURRENT_TIMESTAMP,
        'source_systems', json_build_array('MSSQL', 'Oracle', 'PostgreSQL')
    );

    RETURN v_unified_data;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Stored Procedures for Complex Operations
-- ==========================================

-- Procedure to perform distributed backup operation
CREATE OR REPLACE FUNCTION remarks_main.sp_distributed_backup()
RETURNS JSON AS $$
DECLARE
    v_main_count INTEGER;
    v_archive_count INTEGER;
    v_summary_count INTEGER;
    v_backup_info JSON;
BEGIN
    -- Count records in each schema
    SELECT COUNT(*) INTO v_main_count FROM remarks_main.remark;
    SELECT COUNT(*) INTO v_archive_count FROM remarks_remote1.remark_archive;
    SELECT COUNT(*) INTO v_summary_count FROM remarks_remote2.remark_summary;

    -- Create backup tables with timestamp
    EXECUTE format('CREATE TABLE remarks_main.remark_backup_%s AS SELECT * FROM remarks_main.remark', 
                   to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'));

    EXECUTE format('CREATE TABLE remarks_remote1.archive_backup_%s AS SELECT * FROM remarks_remote1.remark_archive', 
                   to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'));

    EXECUTE format('CREATE TABLE remarks_remote2.summary_backup_%s AS SELECT * FROM remarks_remote2.remark_summary', 
                   to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'));

    v_backup_info := json_build_object(
        'success', true,
        'backup_timestamp', CURRENT_TIMESTAMP,
        'records_backed_up', json_build_object(
            'main_remarks', v_main_count,
            'archived_remarks', v_archive_count,
            'summary_records', v_summary_count
        ),
        'backup_tables_created', json_build_array(
            format('remark_backup_%s', to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS')),
            format('archive_backup_%s', to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS')),
            format('summary_backup_%s', to_char(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'))
        )
    );

    RETURN v_backup_info;

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'timestamp', CURRENT_TIMESTAMP
        );
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Performance Monitoring Functions
-- ==========================================

-- Function to monitor cross-schema query performance
CREATE OR REPLACE FUNCTION remarks_main.fn_performance_monitor()
RETURNS TABLE(
    operation_type TEXT,
    execution_time_ms NUMERIC,
    records_processed INTEGER,
    schema_accessed TEXT
) AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_count INTEGER;
BEGIN
    -- Test main schema query performance
    v_start_time := clock_timestamp();
    SELECT COUNT(*) INTO v_count FROM remarks_main.remark;
    v_end_time := clock_timestamp();

    RETURN QUERY SELECT 
        'SELECT_MAIN'::TEXT,
        EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000,
        v_count,
        'remarks_main'::TEXT;

    -- Test archive schema query performance
    v_start_time := clock_timestamp();
    SELECT COUNT(*) INTO v_count FROM remarks_remote1.remark_archive;
    v_end_time := clock_timestamp();

    RETURN QUERY SELECT 
        'SELECT_ARCHIVE'::TEXT,
        EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000,
        v_count,
        'remarks_remote1'::TEXT;

    -- Test cross-schema join performance
    v_start_time := clock_timestamp();
    SELECT COUNT(*) INTO v_count 
    FROM remarks_main.remark r 
    JOIN remarks_remote2.remark_summary rs ON r.studentId = rs.studentId;
    v_end_time := clock_timestamp();

    RETURN QUERY SELECT 
        'CROSS_SCHEMA_JOIN'::TEXT,
        EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000,
        v_count,
        'remarks_main+remarks_remote2'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- Test the Functions
-- ==========================================

-- Test the distributed functions
DO $$
DECLARE
    v_result JSON;
    v_test_results TEXT := '';
BEGIN
    RAISE NOTICE 'Testing PostgreSQL distributed functions...';

    SELECT remarks_main.fn_distributed_insert_remark(1, 1, 'Test remark from distributed function') INTO v_result;
    RAISE NOTICE 'Distributed insert result: %', v_result;

    SELECT remarks_main.fn_unified_student_view(1) INTO v_result;
    RAISE NOTICE 'Unified student view: %', v_result::TEXT;

    RAISE NOTICE 'Performance monitoring results:';
    FOR v_test_results IN 
        SELECT operation_type || ': ' || execution_time_ms::TEXT || 'ms (' || records_processed::TEXT || ' records)'
        FROM remarks_main.fn_performance_monitor()
    LOOP
        RAISE NOTICE '%', v_test_results;
    END LOOP;

    RAISE NOTICE 'PostgreSQL distributed functions testing completed!';
END;
$$;
