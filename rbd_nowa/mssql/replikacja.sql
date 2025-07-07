--USE SchoolDB;
--EXEC sp_droppublication  @publication = N'SchoolDB_StudentsOnly';
--EXEC sp_replicationdboption @dbname='SchoolDB', @optname='publish', @value='false';


USE master;
GO

EXEC sp_dropdistributor 
    @no_checks = 1, 
    @ignore_distributor = 1;

EXEC sp_adddistributor 
     @distributor = @@SERVERNAME,
     @password    = N'StrongDistributionPwd!';

EXEC sp_adddistributiondb
     @database      = N'distribution',
     @data_folder   = N'C:\MSSQL\Data',
     @log_folder    = N'C:\MSSQL\Data',
     @security_mode = 1;
GO

RECONFIGURE;

EXEC sp_adddistpublisher 
     @publisher          = @@SERVERNAME,          
     @distribution_db    = N'distribution',
     @working_directory  = N'C:\ReplData',
     @security_mode      = 1;                     
GO

EXEC sp_serveroption N'MSSQL_REPLICA', 'rpc',       'true';
EXEC sp_serveroption N'MSSQL_REPLICA', 'rpc out',   'true';
EXEC sp_serveroption N'MSSQL_REPLICA', 'data access','true';
GO

RECONFIGURE;

EXEC sp_replflush

USE SchoolDB;
GO

--USE SchoolDB;
EXEC sp_droppublication  @publication = N'SchoolDB_StudentsOnly';
EXEC sp_replicationdboption @dbname='SchoolDB', @optname='publish', @value='false';


EXEC sp_replicationdboption 
     @dbname  = N'SchoolDB',
     @optname = N'publish',
     @value   = N'true';                 
GO

SELECT name
FROM msdb.dbo.sysjobs
WHERE name LIKE '%SchoolDB%Log Reader%';

SELECT  s.session_id,
        s.login_name,
        r.status,
        r.command,
        DB_NAME(r.database_id) AS db,
        r.wait_type
FROM    sys.dm_exec_sessions s
JOIN    sys.dm_exec_requests r ON s.session_id = r.session_id
WHERE   r.command LIKE 'sp_repl%';

SELECT *
FROM sys.dm_exec_requests
WHERE command LIKE 'sp_repl%';

EXEC sp_addpublication
     @publication       = N'SchoolDB_StudentsOnly',
     @repl_freq         = N'continuous',
     @sync_method       = N'concurrent',
     @replicate_ddl     = 1;

EXEC sp_addarticle
     @publication       = N'SchoolDB_StudentsOnly',
     @article           = N'students',
     @source_object     = N'students',
     @type              = N'logbased',
     @identityrangemanagementoption = N'MANUAL';

EXEC sp_changepublication 
     @publication = N'SchoolDB_StudentsOnly',
     @property    = N'status',
     @value       = N'active';
GO

SELECT *
FROM   syspublications sp
WHERE  publication = N'SchoolDB_StudentsOnly';

EXEC sp_dropsubscription
    @publication = N'SchoolDB_StudentsOnly',
    @subscriber = N'MSSQL_REPLICA',
    @destination_db = N'SchoolDB_Replica',
	@article = N'all';

EXEC sp_addsubscription
     @publication       = N'SchoolDB_StudentsOnly',
     @subscriber        = N'127.0.0.1,1434',
     @destination_db    = N'SchoolDB_Replica',
     @subscription_type = N'Push',
     @sync_type         = N'automatic',
     @article           = N'all',
     @update_mode       = N'read only';
GO

EXEC sp_addpushsubscription_agent
     @publication              = N'SchoolDB_StudentsOnly',
     @subscriber               = N'127.0.0.1,1434',
     @subscriber_db            = N'SchoolDB_Replica',
     @subscriber_security_mode = 0,
     @subscriber_login         = N'repl_user',
     @subscriber_password      = N'Pa55w0rd!',
     @frequency_type           = 64;
GO

EXEC sp_addpublication_snapshot
    @publication             = N'SchoolDB_StudentsOnly',
    @publisher_security_mode = 1;
GO

USE SchoolDB;
GO
SELECT  p.name,
        p.snapshot_jobid,
        sj.name  AS snapshot_jobname
FROM    syspublications            AS p
LEFT JOIN msdb.dbo.sysjobs AS sj   ON p.snapshot_jobid = sj.job_id
WHERE   p.name = N'SchoolDB_StudentsOnly';

-- tu bedzie nazwa ziomka od snaphotow

EXEC msdb.dbo.sp_start_job
     @job_name = N'DESKTOP-U8K1QHA-SchoolDB-SchoolDB_StudentsOnly-1';

EXEC msdb.dbo.sp_help_jobstep 
     @job_name = N'DESKTOP-U8K1QHA-SchoolDB-SchoolDB_StudentsOnly-1', 
     @step_id  = 2;        -- Run agent

EXEC msdb.dbo.sp_help_jobhistory
     @job_name = N'DESKTOP-U8K1QHA-SchoolDB-SchoolDB_StudentsOnly-1',
     @mode     = 'FULL';

EXEC msdb.dbo.sp_start_job 
     @job_name = N'DESKTOP-U8K1QHA-SchoolDB_StudentsOnly-MSSQL_REPLICA-SchoolDB_Replica';

USE distribution;
GO
EXEC sp_replmonitorhelpsubscription 
    @publisher = @@SERVERNAME,
    @publisher_db = N'SchoolDB',
    @publication = N'SchoolDB_StudentsOnly';

USE distribution;
GO
EXEC sp_replmonitorhelpsubscription 
    @publisher = N'DESKTOP-U8K1QHA',
    @publication = N'SchoolDB_StudentsOnly';

SELECT name 
FROM msdb.dbo.sysjobs 
WHERE name LIKE '%StudentsOnly%' AND name LIKE '%MSSQL_REPLICA%';


EXEC msdb.dbo.sp_help_jobhistory 
    @job_name = N'DESKTOP-U8K1QHA-SchoolDB-MSSQL_REPLICA-433577A05907464885AA96C1B2D1A5BB',
    @mode = 'FULL';
