
-- ==========================================
-- MSSQL Data Replication Configuration Script
-- School Management System - Replication Setup
-- ==========================================

USE master;
GO

-- ==========================================
-- SECTION 1: Configure Distribution Database
-- ==========================================

-- Enable replication
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Agent XPs', 1;
RECONFIGURE;
GO

-- Configure the server as a distributor
EXEC sp_adddistributor 
    @distributor = @@SERVERNAME,
    @password = 'StrongPassword123!';
GO

-- Create distribution database
EXEC sp_adddistributiondb 
    @database = 'DistributionDB',
    @data_folder = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data',
    @log_folder = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data',
    @security_mode = 1;
GO

-- ==========================================
-- SECTION 2: Configure Publisher
-- ==========================================

USE SchoolDB;
GO

-- Add the current server as a publisher
EXEC sp_adddistpublisher 
    @publisher = @@SERVERNAME,
    @distribution_db = 'DistributionDB',
    @working_directory = 'C:\ReplData';
GO

-- Enable database for replication
EXEC sp_replicationdboption 
    @dbname = 'SchoolDB',
    @optname = 'publish',
    @value = 'true';
GO

-- ==========================================
-- SECTION 3: Create Transactional Replication Publication
-- ==========================================

-- Create transactional publication for student data
EXEC sp_addpublication 
    @publication = 'SchoolDB_StudentData',
    @description = 'Transactional publication for student management data',
    @sync_method = 'concurrent',
    @retention = 0,
    @allow_push = 'true',
    @allow_pull = 'true',
    @allow_anonymous = 'false',
    @enabled_for_internet = 'false',
    @snapshot_in_defaultfolder = 'true',
    @allow_subscription_copy = 'false',
    @add_to_active_directory = 'false',
    @repl_freq = 'continuous',
    @status = 'active',
    @independent_agent = 'true',
    @immediate_sync = 'false',
    @allow_sync_tran = 'false',
    @autogen_sync_procs = 'false',
    @allow_queued_tran = 'false',
    @allow_dts = 'false',
    @replicate_ddl = 1;
GO

-- Add articles (tables) to the publication
EXEC sp_addarticle 
    @publication = 'SchoolDB_StudentData',
    @article = 'students',
    @source_object = 'students',
    @type = 'logbased',
    @description = 'Students table for replication',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @identityrangemanagementoption = 'manual',
    @destination_table = 'students',
    @destination_owner = 'dbo';
GO

-- Create procedure to monitor replication status
CREATE OR ALTER PROCEDURE sp_MonitorReplicationStatus
AS
BEGIN
    SET NOCOUNT ON;

    -- Check publication status
    SELECT 'Publication Status' as ReportSection;
    SELECT 
        p.name as PublicationName,
        p.repl_freq as ReplicationFrequency,
        p.status as Status,
        p.retention as RetentionPeriod,
        p.sync_method as SyncMethod
    FROM dbo.syspublications p;

    -- Check subscription status
    SELECT 'Subscription Status' as ReportSection;
    SELECT 
        s.publication as PublicationName,
        s.subscriber_server as SubscriberServer,
        s.subscriber_db as SubscriberDatabase,
        s.subscription_type as SubscriptionType,
        s.sync_type as SyncType,
        s.status as Status
    FROM dbo.syssubscriptions s;

    -- Check replication agents
    SELECT 'Agent Status' as ReportSection;
    SELECT 
        j.name as JobName,
        j.enabled as IsEnabled,
        ja.last_run_date,
        ja.last_run_time,
        CASE ja.last_run_outcome
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 5 THEN 'Unknown'
        END as LastRunOutcome
    FROM msdb.dbo.sysjobs j
        INNER JOIN msdb.dbo.sysjobactivity ja ON j.job_id = ja.job_id
    WHERE j.category_id IN (10, 11, 12, 13, 14, 15, 16) -- Replication categories
    ORDER BY ja.last_run_date DESC, ja.last_run_time DESC;
END;
GO

-- Create procedure to manually start snapshot agents
CREATE OR ALTER PROCEDURE sp_StartSnapshotAgents
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JobName NVARCHAR(128);

    -- Cursor to iterate through snapshot agent jobs
    DECLARE snapshot_cursor CURSOR FOR
    SELECT j.name
    FROM msdb.dbo.sysjobs j
    WHERE j.category_id = 13 -- Snapshot Agent category
    AND j.enabled = 1;

    OPEN snapshot_cursor;
    FETCH NEXT FROM snapshot_cursor INTO @JobName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC msdb.dbo.sp_start_job @job_name = @JobName;
            PRINT 'Started snapshot agent: ' + @JobName;
        END TRY
        BEGIN CATCH
            PRINT 'Failed to start snapshot agent: ' + @JobName + ' - ' + ERROR_MESSAGE();
        END CATCH;

        FETCH NEXT FROM snapshot_cursor INTO @JobName;
    END;

    CLOSE snapshot_cursor;
    DEALLOCATE snapshot_cursor;
END;
GO

PRINT 'MSSQL Replication configuration completed successfully!';
PRINT 'Note: Adjust server names and paths according to your environment.';
PRINT 'Ensure SQL Server Agent is running on all participating servers.';
