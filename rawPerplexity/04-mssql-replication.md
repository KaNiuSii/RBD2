# SQL Server Replication Setup Script

## 1. Configure Distribution Server

```sql
-- Connect to the main SQL Server instance
USE master;
GO

-- Check if distribution is already configured
EXEC sp_get_distributor;
GO

-- Configure the local server as a distributor
EXEC sp_adddistributor @distributor = @@SERVERNAME,
    @password = 'DistributorPassword123!';
GO

-- Create distribution database
EXEC sp_adddistributiondb 
    @database = 'distribution',
    @data_folder = 'C:\Database\Distribution',
    @log_folder = 'C:\Database\Distribution',
    @log_file_size = 2,
    @min_distretention = 0,
    @max_distretention = 72,
    @history_retention = 48,
    @security_mode = 1;
GO

-- Add the current server as a publisher using the distributor
EXEC sp_adddistpublisher 
    @publisher = @@SERVERNAME,
    @distribution_db = 'distribution',
    @security_mode = 1,
    @working_directory = 'C:\ReplData',
    @trusted = 'false',
    @thirdparty_flag = 0,
    @publisher_type = 'MSSQLSERVER';
GO
```

## 2. Enable Database for Replication

```sql
-- Enable the SchoolManagement database for transactional replication
USE master;
GO

EXEC sp_replicationdboption 
    @dbname = 'SchoolManagement',
    @optname = 'publish',
    @value = 'true';
GO

-- Verify database is enabled for replication
SELECT name, is_published, is_subscribed, is_merge_published, is_distributor
FROM sys.databases
WHERE name = 'SchoolManagement';
GO
```

## 3. Create Publication

```sql
-- Switch to the SchoolManagement database
USE SchoolManagement;
GO

-- Add transactional publication
EXEC sp_addpublication 
    @publication = 'SchoolManagement_Publication',
    @description = 'Transactional publication of SchoolManagement database',
    @sync_method = 'concurrent',
    @retention = 0,
    @allow_push = 'true',
    @allow_pull = 'true',
    @allow_anonymous = 'false',
    @enabled_for_internet = 'false',
    @snapshot_in_defaultfolder = 'true',
    @alt_snapshot_folder = '',
    @compress_snapshot = 'false',
    @ftp_port = 21,
    @ftp_login = 'anonymous',
    @allow_subscription_copy = 'false',
    @add_to_active_directory = 'false',
    @repl_freq = 'continuous',
    @status = 'active',
    @independent_agent = 'true',
    @immediate_sync = 'true',
    @allow_sync_tran = 'false',
    @autogen_sync_procs = 'false',
    @allow_queued_tran = 'false',
    @allow_dts = 'false',
    @replicate_ddl = 1,
    @allow_initialize_from_backup = 'false',
    @enabled_for_p2p = 'false',
    @enabled_for_het_sub = 'false';
GO
```

## 4. Add Articles to Publication

```sql
-- Add key tables to the publication

-- Add students table
EXEC sp_addarticle 
    @publication = 'SchoolManagement_Publication',
    @article = 'students',
    @source_owner = 'dbo',
    @source_object = 'students',
    @type = 'logbased',
    @description = 'Students table for replication',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @identityrangemanagementoption = 'manual',
    @destination_table = 'students',
    @destination_owner = 'dbo',
    @vertical_partition = 'false',
    @ins_cmd = 'CALL sp_MSins_dbostudents',
    @del_cmd = 'CALL sp_MSdel_dbostudents',
    @upd_cmd = 'SCALL sp_MSupd_dbostudents';
GO

-- Add teachers table
EXEC sp_addarticle 
    @publication = 'SchoolManagement_Publication',
    @article = 'teachers',
    @source_owner = 'dbo',
    @source_object = 'teachers',
    @type = 'logbased',
    @description = 'Teachers table for replication',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @identityrangemanagementoption = 'manual',
    @destination_table = 'teachers',
    @destination_owner = 'dbo';
GO

-- Add groups table
EXEC sp_addarticle 
    @publication = 'SchoolManagement_Publication',
    @article = 'groups',
    @source_owner = 'dbo',
    @source_object = 'groups',
    @type = 'logbased',
    @description = 'Groups table for replication',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @identityrangemanagementoption = 'manual',
    @destination_table = 'groups',
    @destination_owner = 'dbo';
GO

-- Add marks table
EXEC sp_addarticle 
    @publication = 'SchoolManagement_Publication',
    @article = 'marks',
    @source_owner = 'dbo',
    @source_object = 'marks',
    @type = 'logbased',
    @description = 'Marks table for replication',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @identityrangemanagementoption = 'manual',
    @destination_table = 'marks',
    @destination_owner = 'dbo';
GO

-- Add lessons table
EXEC sp_addarticle 
    @publication = 'SchoolManagement_Publication',
    @article = 'lessons',
    @source_owner = 'dbo',
    @source_object = 'lessons',
    @type = 'logbased',
    @description = 'Lessons table for replication',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @identityrangemanagementoption = 'manual',
    @destination_table = 'lessons',
    @destination_owner = 'dbo';
GO

-- Add lookup tables
EXEC sp_addarticle 
    @publication = 'SchoolManagement_Publication',
    @article = 'subjects',
    @source_owner = 'dbo',
    @source_object = 'subjects',
    @type = 'logbased',
    @description = 'Subjects lookup table',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @destination_table = 'subjects',
    @destination_owner = 'dbo';
GO

EXEC sp_addarticle 
    @publication = 'SchoolManagement_Publication',
    @article = 'genders',
    @source_owner = 'dbo',
    @source_object = 'genders',
    @type = 'logbased',
    @description = 'Genders lookup table',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @destination_table = 'genders',
    @destination_owner = 'dbo';
GO

EXEC sp_addarticle 
    @publication = 'SchoolManagement_Publication',
    @article = 'years',
    @source_owner = 'dbo',
    @source_object = 'years',
    @type = 'logbased',
    @description = 'Years lookup table',
    @creation_script = null,
    @pre_creation_cmd = 'drop',
    @schema_option = 0x000000000803509F,
    @destination_table = 'years',
    @destination_owner = 'dbo';
GO
```

## 5. Create Snapshot Agent

```sql
-- Add snapshot agent for the publication
EXEC sp_addpublication_snapshot 
    @publication = 'SchoolManagement_Publication',
    @frequency_type = 1,
    @frequency_interval = 1,
    @frequency_relative_interval = 1,
    @frequency_recurrence_factor = 0,
    @frequency_subday = 8,
    @frequency_subday_interval = 1,
    @active_start_time_of_day = 0,
    @active_end_time_of_day = 235959,
    @active_start_date = 0,
    @active_end_date = 0,
    @job_login = NULL,
    @job_password = NULL,
    @publisher_security_mode = 1;
GO

-- Start the snapshot agent job
EXEC sp_startpublication_snapshot 
    @publication = 'SchoolManagement_Publication';
GO
```

## 6. Setup Subscriber Server (Run on the second SQL Server instance)

```sql
-- Connect to the subscriber server
-- Replace 'SUBSCRIBER_SERVER' with your actual subscriber server name
USE master;
GO

-- Create the subscription database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SchoolManagement_Replica')
BEGIN
    CREATE DATABASE SchoolManagement_Replica;
END
GO

-- Add the distributor to the subscriber
EXEC sp_adddistributor 
    @distributor = 'PUBLISHER_SERVER_NAME',  -- Replace with publisher server name
    @password = 'DistributorPassword123!';
GO
```

## 7. Create Push Subscription (Run on Publisher)

```sql
-- Switch to the SchoolManagement database on the publisher
USE SchoolManagement;
GO

-- Add push subscription
EXEC sp_addsubscription 
    @publication = 'SchoolManagement_Publication',
    @subscriber = 'SUBSCRIBER_SERVER_NAME',  -- Replace with subscriber server name
    @destination_db = 'SchoolManagement_Replica',
    @subscription_type = 'Push',
    @sync_type = 'automatic',
    @article = 'all',
    @update_mode = 'read only',
    @subscriber_type = 0;
GO

-- Add push subscription agent
EXEC sp_addpushsubscription_agent 
    @publication = 'SchoolManagement_Publication',
    @subscriber = 'SUBSCRIBER_SERVER_NAME',  -- Replace with subscriber server name
    @subscriber_db = 'SchoolManagement_Replica',
    @job_login = NULL,
    @job_password = NULL,
    @subscriber_security_mode = 1,
    @frequency_type = 64,
    @frequency_interval = 0,
    @frequency_relative_interval = 0,
    @frequency_recurrence_factor = 0,
    @frequency_subday = 4,
    @frequency_subday_interval = 5,
    @active_start_time_of_day = 0,
    @active_end_time_of_day = 235959,
    @active_start_date = 0,
    @active_end_date = 0,
    @publisher_security_mode = 1;
GO
```

## 8. Monitoring and Validation Scripts

```sql
-- Check replication status
SELECT 
    p.publication_id,
    p.name AS publication_name,
    p.description,
    p.status,
    p.retention,
    p.sync_method,
    p.allow_push,
    p.allow_pull
FROM sys.publications p;
GO

-- Check articles in publication
SELECT 
    a.article_id,
    a.article,
    a.source_object,
    a.destination_object,
    a.type,
    a.status
FROM sys.articles a
JOIN sys.publications p ON a.publication_id = p.publication_id
WHERE p.name = 'SchoolManagement_Publication';
GO

-- Check subscription status
SELECT 
    s.publication_id,
    s.subscriber_server,
    s.subscriber_db,
    s.subscription_type,
    s.sync_type,
    s.status,
    s.update_mode
FROM sys.subscriptions s
JOIN sys.publications p ON s.publication_id = p.publication_id
WHERE p.name = 'SchoolManagement_Publication';
GO

-- Monitor replication agents
SELECT 
    job.name AS job_name,
    job.enabled,
    activity.run_status,
    activity.run_date,
    activity.run_time,
    activity.run_duration,
    activity.message
FROM msdb.dbo.sysjobs job
LEFT JOIN msdb.dbo.sysjobactivity activity ON job.job_id = activity.job_id
WHERE job.name LIKE '%SchoolManagement_Publication%'
ORDER BY activity.run_date DESC, activity.run_time DESC;
GO
```

## 9. Create Replication Performance Monitoring

```sql
-- Create a monitoring procedure
USE SchoolManagement;
GO

CREATE PROCEDURE sp_MonitorReplication
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check publication status
    PRINT 'Publication Status:';
    SELECT 
        name AS Publication,
        status AS Status,
        CASE status 
            WHEN 1 THEN 'Active'
            WHEN 0 THEN 'Inactive'
            ELSE 'Unknown'
        END AS StatusDescription
    FROM sys.publications;
    
    -- Check undistributed commands
    PRINT '';
    PRINT 'Undistributed Commands:';
    SELECT 
        subscriber_server,
        subscriber_db,
        COUNT(*) AS UndistributedCommands
    FROM distribution.dbo.MSrepl_commands c
    INNER JOIN distribution.dbo.MSsubscriptions s ON c.publisher_database_id = s.publisher_database_id
    GROUP BY subscriber_server, subscriber_db;
    
    -- Check agent history
    PRINT '';
    PRINT 'Recent Agent Activity:';
    SELECT TOP 10
        h.agent_id,
        h.runstatus,
        h.start_time,
        h.duration,
        h.comments
    FROM distribution.dbo.MSdistribution_history h
    ORDER BY h.start_time DESC;
END;
GO

-- Create a stored procedure to test replication
CREATE PROCEDURE sp_TestReplication
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TestStudentId INT;
    
    -- Insert a test student
    INSERT INTO students (firstName, lastName, birthday, genderId, groupId)
    VALUES ('Test', 'Student', '2000-01-01', 1, 1);
    
    SET @TestStudentId = SCOPE_IDENTITY();
    PRINT 'Inserted test student with ID: ' + CAST(@TestStudentId AS VARCHAR(10));
    
    -- Wait a moment for replication
    WAITFOR DELAY '00:00:05';
    
    -- Delete the test student
    DELETE FROM students WHERE id = @TestStudentId;
    PRINT 'Deleted test student with ID: ' + CAST(@TestStudentId AS VARCHAR(10));
    
    PRINT 'Check the subscriber database to verify replication occurred.';
END;
GO
```

## 10. Troubleshooting Scripts

```sql
-- Script to check for replication errors
SELECT 
    h.agent_id,
    h.runstatus,
    h.start_time,
    h.duration,
    h.comments,
    h.error_id
FROM distribution.dbo.MSdistribution_history h
WHERE h.runstatus <> 2  -- Not successful
ORDER BY h.start_time DESC;
GO

-- Script to reinitialize subscription if needed
/*
USE SchoolManagement;
GO

EXEC sp_reinitsubscription 
    @publication = 'SchoolManagement_Publication',
    @subscriber = 'SUBSCRIBER_SERVER_NAME',
    @subscriber_db = 'SchoolManagement_Replica';
GO
*/

-- Script to stop and start replication agents
/*
-- Stop distribution agent
EXEC sp_MSstop_agent 
    @agent_type = 'distribution',
    @publication = 'SchoolManagement_Publication',
    @subscriber = 'SUBSCRIBER_SERVER_NAME',
    @subscriber_db = 'SchoolManagement_Replica';

-- Start distribution agent
EXEC sp_MSstart_agent 
    @agent_type = 'distribution',
    @publication = 'SchoolManagement_Publication',
    @subscriber = 'SUBSCRIBER_SERVER_NAME',
    @subscriber_db = 'SchoolManagement_Replica';
*/
```

## 11. Setup Alerts for Replication Monitoring

```sql
-- Create an alert for replication failures
USE msdb;
GO

EXEC msdb.dbo.sp_add_alert 
    @name = 'Replication Failure Alert',
    @message_id = 20572,  -- Replication agent failure
    @severity = 0,
    @category_name = '[Uncategorized]',
    @include_event_description_in = 1;
GO

-- Add notification (requires SQL Server Agent mail configuration)
/*
EXEC msdb.dbo.sp_add_notification 
    @alert_name = 'Replication Failure Alert',
    @operator_name = 'DBA_Team',
    @notification_method = 1;
GO
*/
```

## 12. Validation and Status Check

```sql
-- Final validation script
PRINT 'SQL Server Replication Setup Complete!';
PRINT '=====================================';

SELECT 'Publications created: ' + CAST(COUNT(*) AS VARCHAR(10))
FROM sys.publications;

SELECT 'Articles in publication: ' + CAST(COUNT(*) AS VARCHAR(10))
FROM sys.articles a
JOIN sys.publications p ON a.publication_id = p.publication_id
WHERE p.name = 'SchoolManagement_Publication';

SELECT 'Subscriptions created: ' + CAST(COUNT(*) AS VARCHAR(10))
FROM sys.subscriptions s
JOIN sys.publications p ON s.publication_id = p.publication_id
WHERE p.name = 'SchoolManagement_Publication';

-- Execute monitoring procedure
EXEC sp_MonitorReplication;
```

---

**Next Steps:**
1. Replace server names and connection details with your actual values
2. Ensure SQL Server Agent is running on both publisher and subscriber
3. Configure appropriate network and firewall settings
4. Run the replication test procedure
5. Set up regular monitoring and maintenance jobs
6. Proceed with the linked servers configuration script