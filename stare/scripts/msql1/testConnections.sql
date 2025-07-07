-- Test all linked server connections
PRINT 'Testing Linked Server Connections...';
PRINT '====================================';

-- Test Oracle connection
BEGIN TRY
    SELECT 'Oracle Connection Test - SUCCESS' AS Result, COUNT(*) AS RecordCount
    FROM ORACLE_LINK..contracts;
END TRY
BEGIN CATCH
    SELECT 'Oracle Connection Test - FAILED' AS Result, ERROR_MESSAGE() AS Error;
END CATCH

-- Test PostgreSQL connection
BEGIN TRY
    SELECT 'PostgreSQL Connection Test - SUCCESS' AS Result, COUNT(*) AS RecordCount
    FROM OPENQUERY(POSTGRES_LINK, 'SELECT COUNT(*) FROM remarks.remark');
END TRY
BEGIN CATCH
    SELECT 'PostgreSQL Connection Test - FAILED' AS Result, ERROR_MESSAGE() AS Error;
END CATCH

-- Test Second SQL Server connection
BEGIN TRY
    SELECT 'SQL2 Connection Test - SUCCESS' AS Result, COUNT(*) AS RecordCount
    FROM SQL2.SchoolManagement_Replica.dbo.students;
END TRY
BEGIN CATCH
    SELECT 'SQL2 Connection Test - FAILED' AS Result, ERROR_MESSAGE() AS Error;
END CATCH

-- Test Excel connection (if file exists)
BEGIN TRY
    SELECT 'Excel Connection Test - SUCCESS' AS Result, COUNT(*) AS RecordCount
    FROM EXCEL_LINK...[Sheet1$];
END TRY
BEGIN CATCH
    SELECT 'Excel Connection Test - FAILED' AS Result, ERROR_MESSAGE() AS Error;
END CATCH

-- Create a view to show linked server security
CREATE VIEW vw_LinkedServerSecurity AS
SELECT 
    s.name AS LinkedServerName,
    s.product,
    s.provider,
    ll.local_principal_id,
    ISNULL(sp.name, 'All Logins') AS LocalLogin,
    ll.remote_name AS RemoteLogin,
    CASE ll.uses_self_credential 
        WHEN 1 THEN 'Uses Windows Authentication'
        ELSE 'Uses Specified Credentials'
    END AS AuthenticationMethod,
    s.is_data_access_enabled,
    s.is_rpc_out_enabled
FROM sys.servers s
LEFT JOIN sys.linked_logins ll ON s.server_id = ll.server_id
LEFT JOIN sys.server_principals sp ON ll.local_principal_id = sp.principal_id
WHERE s.is_linked = 1;
GO

-- Comprehensive validation script
PRINT 'Linked Servers Configuration Complete!';
PRINT '=====================================';

-- Show configured linked servers
SELECT 'Linked servers configured: ' + CAST(COUNT(*) AS VARCHAR(10))
FROM sys.servers 
WHERE is_linked = 1;

-- Execute monitoring procedures
EXEC sp_MonitorLinkedServers;
EXEC sp_TestAllLinkedServers;

-- Test distributed views
SELECT TOP 5 * FROM vw_StudentCompleteProfile;
SELECT TOP 5 * FROM vw_FinancialSummary;
SELECT TOP 5 * FROM vw_BehavioralSummary;

PRINT 'All linked servers are configured and ready for distributed operations.';