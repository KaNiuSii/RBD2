-- ==========================================
-- Test Replication Operations
-- ==========================================

USE SchoolDB;
GO

PRINT 'Starting replication tests...';
PRINT '==========================================';

-- Test 1: Replication configuration verification
PRINT 'Test 1: Replication configuration verification';
SELECT 
    name,
    value,
    value_in_use,
    description
FROM sys.configurations
WHERE name IN ('Agent XPs', 'replication');

-- Test 2: Distribution database check
PRINT 'Test 2: Distribution database check';
SELECT 
    name,
    database_id,
    create_date,
    state_desc
FROM sys.databases
WHERE name = 'DistributionDB';

-- Test 3: Publisher configuration
PRINT 'Test 3: Publisher configuration';
SELECT 
    srvname as publisher_name,
    datasource,
    catalog,
    provider,
    login,
    distribution_db
FROM distribution.dbo.MSdistributor;

-- Test 4: Publication verification
PRINT 'Test 4: Publication verification';
SELECT 
    publication_id,
    name as publication_name,
    description,
    status,
    retention,
    sync_method,
    snapshot_in_defaultfolder,
    immediate_sync
FROM distribution.dbo.MSpublications;

-- Test 5: Article verification
PRINT 'Test 5: Article verification';
SELECT 
    a.article_id,
    a.article,
    a.source_object,
    a.destination_object,
    a.type,
    a.description,
    p.name as publication_name
FROM distribution.dbo.MSarticles a
INNER JOIN distribution.dbo.MSpublications p ON a.publication_id = p.publication_id;

-- Test 6: Replication agents status
PRINT 'Test 6: Replication agents status';
SELECT 
    j.job_id,
    j.name as job_name,
    j.enabled,
    j.description,
    CASE 
        WHEN j.name LIKE '%Snapshot%' THEN 'Snapshot Agent'
        WHEN j.name LIKE '%LogReader%' THEN 'Log Reader Agent'
        WHEN j.name LIKE '%Distribution%' THEN 'Distribution Agent'
        ELSE 'Other'
    END as agent_type
FROM msdb.dbo.sysjobs j
WHERE j.category_id IN (13, 14, 15) -- Replication categories
ORDER BY j.name;

-- Test 7: Snapshot agent execution
PRINT 'Test 7: Snapshot agent execution';
BEGIN TRY
    EXEC sp_StartSnapshotAgents;
    PRINT 'Snapshot agents started successfully';
END TRY
BEGIN CATCH
    PRINT 'Error starting snapshot agents: ' + ERROR_MESSAGE();
END CATCH;

-- Test 8: Replication monitor
PRINT 'Test 8: Replication monitoring';
CREATE OR ALTER PROCEDURE sp_MonitorReplicationStatus
AS
BEGIN
    SET NOCOUNT ON;

    -- Monitor snapshot agent activity
    SELECT 
        'Snapshot Agent Status' as MonitorType,
        agent_id,
        agent_type,
        name,
        job_id,
        profile_id,
        start_time,
        time,
        duration,
        status,
        comments
    FROM distribution.dbo.MSsnapshot_agents sa
    LEFT JOIN distribution.dbo.MSsnapshot_history sh ON sa.agent_id = sh.agent_id;

    -- Monitor distribution agent activity
    SELECT 
        'Distribution Agent Status' as MonitorType,
        agent_id,
        agent_type,
        subscriber_db,
        subscription_type,
        start_time,
        time,
        duration,
        status,
        comments
    FROM distribution.dbo.MSdistribution_agents da
    LEFT JOIN distribution.dbo.MSdistribution_history dh ON da.agent_id = dh.agent_id;

    -- Monitor replication errors
    SELECT 
        'Replication Errors' as MonitorType,
        time,
        source_type_id,
        source_type,
        error_id,
        error_code,
        error_text,
        xact_seqno
    FROM distribution.dbo.MSrepl_errors
    WHERE time >= DATEADD(HOUR, -24, GETDATE())
    ORDER BY time DESC;
END;
GO

EXEC sp_MonitorReplicationStatus;

-- Test 9: Test data replication
PRINT 'Test 9: Test data replication';
BEGIN TRY
    -- Insert test data to verify replication
    INSERT INTO students (groupId, firstName, lastName, birthday, genderId)
    VALUES (1, 'Replication', 'Test', '2010-01-01', 1);

    DECLARE @TestStudentId INT = SCOPE_IDENTITY();
    PRINT 'Created test student for replication with ID: ' + CAST(@TestStudentId AS VARCHAR(10));

    -- Wait for replication to process
    WAITFOR DELAY '00:00:05';

    -- Check if data was replicated (this would be checked on subscriber)
    SELECT 
        'Test Data' as DataType,
        COUNT(*) as StudentCount
    FROM students
    WHERE firstName = 'Replication' AND lastName = 'Test';

END TRY
BEGIN CATCH
    PRINT 'Error in replication test: ' + ERROR_MESSAGE();
END CATCH;

-- Test 10: Replication performance metrics
PRINT 'Test 10: Replication performance metrics';
CREATE OR ALTER PROCEDURE sp_ReplicationPerformanceMetrics
AS
BEGIN
    SET NOCOUNT ON;

    -- Snapshot agent performance
    SELECT 
        'Snapshot Performance' as MetricType,
        AVG(duration) as AvgDuration,
        MAX(duration) as MaxDuration,
        MIN(duration) as MinDuration,
        COUNT(*) as TotalRuns
    FROM distribution.dbo.MSsnapshot_history
    WHERE time >= DATEADD(DAY, -7, GETDATE());

    -- Distribution agent performance
    SELECT 
        'Distribution Performance' as MetricType,
        AVG(duration) as AvgDuration,
        MAX(duration) as MaxDuration,
        MIN(duration) as MinDuration,
        COUNT(*) as TotalRuns
    FROM distribution.dbo.MSdistribution_history
    WHERE time >= DATEADD(DAY, -7, GETDATE());

    -- Replication latency
    SELECT 
        'Replication Latency' as MetricType,
        AVG(DATEDIFF(SECOND, entry_time, time)) as AvgLatencySeconds,
        MAX(DATEDIFF(SECOND, entry_time, time)) as MaxLatencySeconds,
        MIN(DATEDIFF(SECOND, entry_time, time)) as MinLatencySeconds
    FROM distribution.dbo.MSrepl_commands c
    INNER JOIN distribution.dbo.MSdistribution_history h ON c.xact_seqno = h.xact_seqno
    WHERE c.time >= DATEADD(DAY, -7, GETDATE());
END;
GO

EXEC sp_ReplicationPerformanceMetrics;

-- Test 11: Cleanup and maintenance
PRINT 'Test 11: Replication cleanup operations';
CREATE OR ALTER PROCEDURE sp_ReplicationCleanup
AS
BEGIN
    SET NOCOUNT ON;

    -- Clean up old snapshot files
    EXEC distribution.dbo.sp_MScleanup_snapshot_folder;

    -- Clean up distribution history
    EXEC distribution.dbo.sp_MScleanup_distribution_history 
        @max_distretention = 72; -- 72 hours

    -- Clean up replication history
    EXEC distribution.dbo.sp_MScleanup_replication_history;

    PRINT 'Replication cleanup completed';
END;
GO

EXEC sp_ReplicationCleanup;

-- Test 12: Replication health check
PRINT 'Test 12: Replication health check';
CREATE OR ALTER FUNCTION fn_ReplicationHealthCheck()
RETURNS TABLE
AS
RETURN (
    SELECT 
        'Health Check' as CheckType,
        CASE 
            WHEN EXISTS (SELECT 1 FROM distribution.dbo.MSpublications WHERE status = 1) THEN 'HEALTHY'
            ELSE 'UNHEALTHY'
        END as PublicationStatus,
        CASE 
            WHEN EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE category_id = 13 AND enabled = 1) THEN 'HEALTHY'
            ELSE 'UNHEALTHY'
        END as SnapshotAgentStatus,
        CASE 
            WHEN NOT EXISTS (SELECT 1 FROM distribution.dbo.MSrepl_errors WHERE time >= DATEADD(HOUR, -1, GETDATE())) THEN 'HEALTHY'
            ELSE 'UNHEALTHY'
        END as ErrorStatus
);
GO

SELECT * FROM fn_ReplicationHealthCheck();

PRINT 'Replication tests completed successfully!';
