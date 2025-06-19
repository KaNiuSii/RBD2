-- Procedure to monitor linked server performance
CREATE PROCEDURE sp_MonitorLinkedServers
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check linked server configurations
    SELECT 
        s.name AS LinkedServerName,
        s.product AS Product,
        s.provider AS Provider,
        s.data_source AS DataSource,
        s.is_linked AS IsLinked,
        s.is_data_access_enabled AS DataAccessEnabled,
        s.is_rpc_out_enabled AS RPCOutEnabled
    FROM sys.servers s
    WHERE s.is_linked = 1;
    
    -- Check login mappings
    SELECT 
        ll.server_id,
        s.name AS LinkedServerName,
        ll.local_principal_id,
        ISNULL(sp.name, 'All Logins') AS LocalLogin,
        ll.remote_name AS RemoteLogin,
        ll.uses_self_credential AS UsesSelfCredential
    FROM sys.linked_logins ll
    JOIN sys.servers s ON ll.server_id = s.server_id
    LEFT JOIN sys.server_principals sp ON ll.local_principal_id = sp.principal_id
    WHERE s.is_linked = 1;
END;
GO

-- Procedure to test all connections
CREATE PROCEDURE sp_TestAllLinkedServers
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TestResults TABLE (
        LinkedServer NVARCHAR(128),
        TestStatus NVARCHAR(50),
        ErrorMessage NVARCHAR(MAX),
        RecordCount INT
    );
    
    -- Test Oracle
    BEGIN TRY
        DECLARE @OracleCount INT;
        SELECT @OracleCount = COUNT(*) FROM ORACLE_LINK..contracts;
        INSERT INTO @TestResults VALUES ('ORACLE_LINK', 'SUCCESS', NULL, @OracleCount);
    END TRY
    BEGIN CATCH
        INSERT INTO @TestResults VALUES ('ORACLE_LINK', 'FAILED', ERROR_MESSAGE(), 0);
    END CATCH
    
    -- Test PostgreSQL
    BEGIN TRY
        DECLARE @PostgresCount INT;
        SELECT @PostgresCount = COUNT(*) 
        FROM OPENQUERY(POSTGRES_LINK, 'SELECT COUNT(*) as cnt FROM remarks.remark');
        INSERT INTO @TestResults VALUES ('POSTGRES_LINK', 'SUCCESS', NULL, @PostgresCount);
    END TRY
    BEGIN CATCH
        INSERT INTO @TestResults VALUES ('POSTGRES_LINK', 'FAILED', ERROR_MESSAGE(), 0);
    END CATCH
    
    -- Test SQL2
    BEGIN TRY
        DECLARE @SQL2Count INT;
        SELECT @SQL2Count = COUNT(*) FROM SQL2.SchoolManagement_Replica.dbo.students;
        INSERT INTO @TestResults VALUES ('SQL2', 'SUCCESS', NULL, @SQL2Count);
    END TRY
    BEGIN CATCH
        INSERT INTO @TestResults VALUES ('SQL2', 'FAILED', ERROR_MESSAGE(), 0);
    END CATCH
    
    -- Return results
    SELECT * FROM @TestResults;
END;
GO