SET search_path TO remarks_main, remarks_remote1, remarks_remote2, public;

-- Test 1: Basic remark operations
DO $$
DECLARE
    v_result JSON;
BEGIN
    -- Test distributed insert
    SELECT remarks_main.fn_distributed_insert_remark(999, 1, 'Test remark from automated test', true) INTO v_result;
    RAISE NOTICE 'Distributed insert result: %', v_result;
END;
$$;

-- Test 2: Paginated remark retrieval
SELECT * FROM remarks_main.fn_get_student_remarks_paginated(1, 2, 1);

-- Test 3: Distributed search
SELECT * FROM remarks_main.fn_distributed_remark_search('excellent', true) LIMIT 10;

-- Test 4: Cross-schema statistics
SELECT * FROM remarks_main.fn_cross_schema_remark_stats();

-- Test 5: Unified student view
DO $$
DECLARE
    v_unified_data JSON;
BEGIN
    SELECT remarks_main.fn_unified_student_view(1) INTO v_unified_data;
    RAISE NOTICE 'Unified student data: %', v_unified_data;
END;
$$;

-- Test 6: Performance monitoring
SELECT * FROM remarks_main.fn_performance_monitor();

-- Test 7: Data migration
DO $$
DECLARE
    v_migration_result JSON;
BEGIN
    SELECT remarks_main.fn_migrate_old_remarks((CURRENT_DATE - INTERVAL '6 months')::DATE) INTO v_migration_result;
    RAISE NOTICE 'Migration result: %', v_migration_result;
END;
$$;

-- Test 8: Distributed backup
DO $$
DECLARE
    v_backup_result JSON;
BEGIN
    SELECT remarks_main.sp_distributed_backup() INTO v_backup_result;
    RAISE NOTICE 'Backup result: %', v_backup_result;
END;
$$;

-- Test 9: Simulated FDW operations
SELECT * FROM remarks_main.fn_simulate_mssql_student_data() LIMIT 5;
SELECT * FROM remarks_main.fn_simulate_oracle_finance_data() LIMIT 5;

-- Test 10: Materialized view operations
REFRESH MATERIALIZED VIEW remarks_main.mv_student_remark_stats;
SELECT * FROM remarks_main.mv_student_remark_stats LIMIT 5;

-- Test 11: Distributed view operations
SELECT * FROM remarks_main.distributed_remarks WHERE studentId = 1;

-- Test 12: Trigger operations
INSERT INTO remarks_main.remark (studentId, teacherId, value) 
VALUES (888, 1, 'Test remark for trigger testing');

-- Verify trigger updated summary
SELECT * FROM remarks_remote2.remark_summary WHERE studentId = 888;

-- Test 13: Complex aggregations
SELECT 
    r.studentId,
    COUNT(*) as total_remarks,
    COUNT(DISTINCT r.teacherId) as unique_teachers,
    MIN(r.created_date) as first_remark,
    MAX(r.created_date) as last_remark,
    AVG(LENGTH(r.value)) as avg_remark_length
FROM remarks_main.remark r
GROUP BY r.studentId
ORDER BY COUNT(*) DESC
LIMIT 10;

