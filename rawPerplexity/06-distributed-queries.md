# Distributed Queries and Ad-Hoc Operations Script

## 1. OPENROWSET Examples for Different Database Systems

```sql
-- Enable Ad Hoc Distributed Queries (if not already enabled)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

USE SchoolManagement;
GO

-- OPENROWSET to Oracle (Contracts)
-- Query Oracle contracts data without linked server
SELECT * FROM OPENROWSET(
    'OraOLEDB.Oracle',
    'Data Source=your_oracle_tns;User Id=contracts_admin;Password=secure_password;',
    'SELECT id, studentId, parentId, startDate, endDate, monthlyAmount FROM contracts WHERE ROWNUM <= 10'
);

-- OPENROWSET to PostgreSQL (Remarks)
-- Query PostgreSQL remarks data without linked server
SELECT * FROM OPENROWSET(
    'MSDASQL',
    'DRIVER={PostgreSQL UNICODE};SERVER=your_postgres_server;PORT=5432;DATABASE=remarks_system;UID=remarks_admin;PWD=secure_password;',
    'SELECT id, studentId, teacherId, value, severity FROM remarks.remark LIMIT 10'
);

-- OPENROWSET to another SQL Server
-- Query replica database data without linked server
SELECT * FROM OPENROWSET(
    'SQLNCLI',
    'Server=your_sql2_server;Database=SchoolManagement_Replica;Trusted_Connection=yes;',
    'SELECT TOP 10 id, firstName, lastName FROM students'
);

-- OPENROWSET to Excel file
-- Query Excel data without linked server
SELECT * FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\Analytics.xlsx;HDR=Yes;IMEX=1',
    'SELECT * FROM [Sheet1$]'
);
```

## 2. OPENQUERY Examples Using Linked Servers

```sql
-- Query Oracle using OPENQUERY
SELECT * FROM OPENQUERY(ORACLE_LINK, '
    SELECT c.id, c.studentId, c.monthlyAmount, p.status, p.amount
    FROM contracts c
    LEFT JOIN payments p ON c.id = p.contractId
    WHERE ROWNUM <= 20
');

-- Query PostgreSQL using OPENQUERY
SELECT * FROM OPENQUERY(POSTGRES_LINK, '
    SELECT r.id, r.studentId, r.teacherId, r.value, r.severity, r.category
    FROM remarks.remark r
    WHERE r.created_date >= CURRENT_DATE - INTERVAL ''30 days''
    ORDER BY r.created_date DESC
    LIMIT 50
');

-- Query second SQL Server using OPENQUERY
SELECT * FROM OPENQUERY(SQL2, '
    SELECT s.id, s.firstName, s.lastName, g.value as GroupName
    FROM SchoolManagement_Replica.dbo.students s
    JOIN SchoolManagement_Replica.dbo.groups g ON s.groupId = g.id
');

-- Complex query with aggregation on remote server
SELECT * FROM OPENQUERY(ORACLE_LINK, '
    SELECT 
        studentId,
        COUNT(*) as total_payments,
        SUM(CASE WHEN status = ''PAID'' THEN amount ELSE 0 END) as paid_amount,
        SUM(CASE WHEN status = ''PENDING'' THEN amount ELSE 0 END) as pending_amount
    FROM contracts c
    JOIN payments p ON c.id = p.contractId
    GROUP BY studentId
');
```

## 3. Multi-Source Distributed Queries

```sql
-- Combine data from all three database systems
SELECT 
    s.id AS StudentId,
    s.firstName + ' ' + s.lastName AS StudentName,
    s.birthday,
    
    -- Contract info from Oracle
    o.contractAmount,
    o.contractStatus,
    
    -- Remarks from PostgreSQL
    p.totalRemarks,
    p.seriousRemarks,
    
    -- Replica status from SQL2
    r.replicationStatus
FROM students s

-- Left join Oracle data
LEFT JOIN (
    SELECT 
        studentId,
        monthlyAmount as contractAmount,
        CASE WHEN endDate > SYSDATE THEN 'ACTIVE' ELSE 'EXPIRED' END as contractStatus
    FROM OPENQUERY(ORACLE_LINK, '
        SELECT studentId, monthlyAmount, endDate FROM contracts
    ')
) o ON s.id = o.studentId

-- Left join PostgreSQL data
LEFT JOIN (
    SELECT 
        studentId,
        COUNT(*) as totalRemarks,
        SUM(CASE WHEN severity IN (''SERIOUS'', ''CRITICAL'') THEN 1 ELSE 0 END) as seriousRemarks
    FROM OPENQUERY(POSTGRES_LINK, '
        SELECT studentId, severity FROM remarks.remark
    ')
    GROUP BY studentId
) p ON s.id = p.studentId

-- Left join SQL2 replica data
LEFT JOIN (
    SELECT 
        id,
        CASE WHEN id IS NOT NULL THEN 'REPLICATED' ELSE 'NOT_REPLICATED' END as replicationStatus
    FROM OPENQUERY(SQL2, '
        SELECT id FROM SchoolManagement_Replica.dbo.students
    ')
) r ON s.id = r.id

WHERE s.id <= 20;
```

## 4. Pass-Through Queries with Local Processing

```sql
-- Process remote Oracle data locally
WITH OraclePayments AS (
    SELECT 
        studentId,
        SUM(amount) as totalAmount,
        COUNT(*) as paymentCount,
        MAX(dueDate) as lastDueDate
    FROM OPENQUERY(ORACLE_LINK, '
        SELECT 
            c.studentId, 
            p.amount, 
            p.dueDate
        FROM contracts c
        JOIN payments p ON c.id = p.contractId
    ')
    GROUP BY studentId
),
PostgresRemarks AS (
    SELECT 
        studentId,
        COUNT(*) as remarkCount,
        STRING_AGG(category, ', ') as categories
    FROM OPENQUERY(POSTGRES_LINK, '
        SELECT studentId, category FROM remarks.remark
        WHERE created_date >= CURRENT_DATE - INTERVAL ''90 days''
    ')
    GROUP BY studentId
)
SELECT 
    s.id,
    s.firstName + ' ' + s.lastName as StudentName,
    op.totalAmount,
    op.paymentCount,
    pr.remarkCount,
    pr.categories,
    -- Local calculation
    CASE 
        WHEN op.totalAmount > 1000 THEN 'High Value'
        WHEN op.totalAmount > 500 THEN 'Medium Value'
        ELSE 'Low Value'
    END as ValueCategory
FROM students s
LEFT JOIN OraclePayments op ON s.id = op.studentId
LEFT JOIN PostgresRemarks pr ON s.id = pr.studentId;
```

## 5. Remote Data Modification Examples

```sql
-- Insert data into remote Oracle database
INSERT INTO OPENQUERY(ORACLE_LINK, 'SELECT id, studentId, parentId, startDate, endDate, monthlyAmount FROM contracts')
VALUES (contracts_seq.NEXTVAL, 1, 1, '2024-01-01', '2024-12-31', 350.00);

-- Update data in remote PostgreSQL database
UPDATE OPENQUERY(POSTGRES_LINK, 'SELECT id, value FROM remarks.remark WHERE id = 1')
SET value = 'Updated remark text from MSSQL';

-- Delete data from remote Oracle database
DELETE FROM OPENQUERY(ORACLE_LINK, 'SELECT id FROM payments WHERE id = 999');

-- More complex remote insert with local data
INSERT INTO OPENQUERY(ORACLE_LINK, 'SELECT id, studentId, parentId, startDate, endDate, monthlyAmount FROM contracts')
SELECT 
    (SELECT MAX(id) + 1 FROM OPENQUERY(ORACLE_LINK, 'SELECT id FROM contracts')),
    s.id,
    ps.parentId,
    GETDATE(),
    DATEADD(YEAR, 1, GETDATE()),
    500.00
FROM students s
JOIN parents_students ps ON s.id = ps.studentId
WHERE s.id = 25;  -- Specific student
```

## 6. Bulk Operations and Data Transfer

```sql
-- Bulk insert from Excel to local table
CREATE TABLE #TempAnalytics (
    StudentId INT,
    AnalysisType NVARCHAR(50),
    Score DECIMAL(5,2),
    Comments NVARCHAR(255)
);

INSERT INTO #TempAnalytics
SELECT 
    StudentId,
    AnalysisType,
    Score,
    Comments
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\StudentAnalytics.xlsx;HDR=Yes;IMEX=1',
    'SELECT * FROM [Analytics$]'
);

-- Transfer data between remote systems
-- From PostgreSQL to Oracle
WITH RecentRemarks AS (
    SELECT 
        studentId,
        COUNT(*) as remarkCount,
        STRING_AGG(severity, ',') as severities
    FROM OPENQUERY(POSTGRES_LINK, '
        SELECT studentId, severity 
        FROM remarks.remark 
        WHERE created_date >= CURRENT_DATE - INTERVAL ''30 days''
    ')
    GROUP BY studentId
)
INSERT INTO OPENQUERY(ORACLE_LINK, 'SELECT id, studentId, parentId, startDate, endDate, monthlyAmount FROM contracts')
SELECT 
    (SELECT MAX(id) + ROW_NUMBER() OVER (ORDER BY s.id) FROM OPENQUERY(ORACLE_LINK, 'SELECT id FROM contracts')),
    s.id,
    ps.parentId,
    GETDATE(),
    DATEADD(YEAR, 1, GETDATE()),
    CASE 
        WHEN rr.remarkCount > 5 THEN 450.00  -- Higher fee for students with many remarks
        ELSE 400.00
    END
FROM students s
JOIN parents_students ps ON s.id = ps.studentId
LEFT JOIN RecentRemarks rr ON s.id = rr.studentId
WHERE NOT EXISTS (
    SELECT 1 FROM OPENQUERY(ORACLE_LINK, 'SELECT studentId FROM contracts') oc 
    WHERE oc.studentId = s.id
);
```

## 7. Dynamic SQL for Remote Queries

```sql
-- Create a procedure for dynamic remote queries
CREATE PROCEDURE sp_ExecuteRemoteQuery
    @ServerName NVARCHAR(128),
    @Query NVARCHAR(MAX),
    @ExecuteLocal BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    
    IF @ExecuteLocal = 1
    BEGIN
        -- Execute on linked server with local processing
        SET @SQL = 'SELECT * FROM OPENQUERY(' + QUOTENAME(@ServerName) + ', ''' + REPLACE(@Query, '''', '''''') + ''')';
    END
    ELSE
    BEGIN
        -- Execute directly on remote server
        SET @SQL = 'EXEC (''' + REPLACE(@Query, '''', '''''') + ''') AT ' + QUOTENAME(@ServerName);
    END
    
    PRINT 'Executing: ' + @SQL;
    EXEC sp_executesql @SQL;
END;
GO

-- Example usage
EXEC sp_ExecuteRemoteQuery 
    @ServerName = 'ORACLE_LINK',
    @Query = 'SELECT COUNT(*) as contract_count FROM contracts',
    @ExecuteLocal = 1;

EXEC sp_ExecuteRemoteQuery 
    @ServerName = 'POSTGRES_LINK',
    @Query = 'SELECT category, COUNT(*) FROM remarks.remark GROUP BY category',
    @ExecuteLocal = 1;
```

## 8. Performance Monitoring for Distributed Queries

```sql
-- Create a procedure to monitor distributed query performance
CREATE PROCEDURE sp_MonitorDistributedQueries
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Monitor active distributed queries
    SELECT 
        s.session_id,
        s.login_name,
        s.host_name,
        r.command,
        r.status,
        r.start_time,
        r.total_elapsed_time,
        t.text as query_text
    FROM sys.dm_exec_sessions s
    JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.command LIKE '%DISTRIBUTED%' 
       OR t.text LIKE '%OPENQUERY%'
       OR t.text LIKE '%OPENROWSET%'
       OR t.text LIKE '%EXEC%AT%';
    
    -- Monitor linked server connections
    SELECT 
        sp.spid,
        sp.loginame,
        sp.hostname,
        sp.program_name,
        sp.cmd,
        sp.status,
        sp.last_batch
    FROM sys.sysprocesses sp
    WHERE sp.program_name LIKE '%SQL Server%'
    AND sp.cmd LIKE '%DISTRIBUTED%';
END;
GO

-- Create a procedure to log distributed query performance
CREATE TABLE DistributedQueryLog (
    LogId INT IDENTITY(1,1) PRIMARY KEY,
    QueryType NVARCHAR(50),
    ServerName NVARCHAR(128),
    QueryText NVARCHAR(MAX),
    StartTime DATETIME2,
    EndTime DATETIME2,
    Duration_ms INT,
    RowsAffected INT,
    ErrorMessage NVARCHAR(MAX),
    UserName NVARCHAR(128)
);

CREATE PROCEDURE sp_LogDistributedQuery
    @QueryType NVARCHAR(50),
    @ServerName NVARCHAR(128),
    @QueryText NVARCHAR(MAX),
    @StartTime DATETIME2,
    @EndTime DATETIME2,
    @RowsAffected INT = NULL,
    @ErrorMessage NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO DistributedQueryLog (
        QueryType,
        ServerName,
        QueryText,
        StartTime,
        EndTime,
        Duration_ms,
        RowsAffected,
        ErrorMessage,
        UserName
    )
    VALUES (
        @QueryType,
        @ServerName,
        @QueryText,
        @StartTime,
        @EndTime,
        DATEDIFF(MILLISECOND, @StartTime, @EndTime),
        @RowsAffected,
        @ErrorMessage,
        SUSER_NAME()
    );
END;
GO
```

## 9. Error Handling for Distributed Operations

```sql
-- Create a robust procedure for distributed operations with error handling
CREATE PROCEDURE sp_ExecuteDistributedOperation
    @OperationType NVARCHAR(20), -- 'SELECT', 'INSERT', 'UPDATE', 'DELETE'
    @TargetServer NVARCHAR(128),
    @Query NVARCHAR(MAX),
    @RetryCount INT = 3,
    @RetryDelay INT = 5 -- seconds
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2 = SYSDATETIME();
    DECLARE @CurrentRetry INT = 0;
    DECLARE @Success BIT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @RowsAffected INT;
    
    WHILE @CurrentRetry < @RetryCount AND @Success = 0
    BEGIN
        BEGIN TRY
            SET @CurrentRetry = @CurrentRetry + 1;
            
            IF @OperationType = 'SELECT'
            BEGIN
                DECLARE @SQL NVARCHAR(MAX) = 'SELECT * FROM OPENQUERY(' + QUOTENAME(@TargetServer) + ', ''' + REPLACE(@Query, '''', '''''') + ''')';
                EXEC sp_executesql @SQL;
                SET @Success = 1;
            END
            ELSE
            BEGIN
                DECLARE @ExecSQL NVARCHAR(MAX) = 'EXEC (''' + REPLACE(@Query, '''', '''''') + ''') AT ' + QUOTENAME(@TargetServer);
                EXEC sp_executesql @ExecSQL;
                SET @RowsAffected = @@ROWCOUNT;
                SET @Success = 1;
            END
            
        END TRY
        BEGIN CATCH
            SET @ErrorMessage = ERROR_MESSAGE();
            
            IF @CurrentRetry < @RetryCount
            BEGIN
                PRINT 'Attempt ' + CAST(@CurrentRetry AS VARCHAR(10)) + ' failed. Retrying in ' + CAST(@RetryDelay AS VARCHAR(10)) + ' seconds...';
                PRINT 'Error: ' + @ErrorMessage;
                
                DECLARE @DelayTime CHAR(8) = CONVERT(CHAR(8), DATEADD(SECOND, @RetryDelay, 0), 108);
                WAITFOR DELAY @DelayTime;
            END
            ELSE
            BEGIN
                PRINT 'All retry attempts failed. Final error: ' + @ErrorMessage;
                THROW;
            END
        END CATCH
    END
    
    -- Log the operation
    EXEC sp_LogDistributedQuery 
        @QueryType = @OperationType,
        @ServerName = @TargetServer,
        @QueryText = @Query,
        @StartTime = @StartTime,
        @EndTime = SYSDATETIME(),
        @RowsAffected = @RowsAffected,
        @ErrorMessage = @ErrorMessage;
    
    IF @Success = 1
        PRINT 'Distributed operation completed successfully after ' + CAST(@CurrentRetry AS VARCHAR(10)) + ' attempts.';
END;
GO
```

## 10. Testing and Validation Scripts

```sql
-- Comprehensive test of all distributed query capabilities
PRINT 'Testing Distributed Query Capabilities...';
PRINT '========================================';

-- Test 1: Basic connectivity
PRINT 'Test 1: Testing basic connectivity to all servers...';
EXEC sp_TestAllLinkedServers;

-- Test 2: OPENQUERY operations
PRINT 'Test 2: Testing OPENQUERY operations...';
BEGIN TRY
    SELECT 'Oracle OPENQUERY Test' as Test, COUNT(*) as Records
    FROM OPENQUERY(ORACLE_LINK, 'SELECT id FROM contracts WHERE ROWNUM <= 5');
    
    SELECT 'PostgreSQL OPENQUERY Test' as Test, COUNT(*) as Records
    FROM OPENQUERY(POSTGRES_LINK, 'SELECT id FROM remarks.remark LIMIT 5');
    
    SELECT 'SQL2 OPENQUERY Test' as Test, COUNT(*) as Records
    FROM OPENQUERY(SQL2, 'SELECT TOP 5 id FROM SchoolManagement_Replica.dbo.students');
    
    PRINT 'All OPENQUERY tests passed!';
END TRY
BEGIN CATCH
    PRINT 'OPENQUERY test failed: ' + ERROR_MESSAGE();
END CATCH

-- Test 3: Complex distributed join
PRINT 'Test 3: Testing complex distributed joins...';
BEGIN TRY
    SELECT TOP 5
        s.id,
        s.firstName + ' ' + s.lastName as StudentName,
        COUNT(o.studentId) as ContractCount,
        COUNT(p.studentId) as RemarkCount
    FROM students s
    LEFT JOIN (
        SELECT studentId FROM OPENQUERY(ORACLE_LINK, 'SELECT studentId FROM contracts')
    ) o ON s.id = o.studentId
    LEFT JOIN (
        SELECT studentId FROM OPENQUERY(POSTGRES_LINK, 'SELECT studentId FROM remarks.remark')
    ) p ON s.id = p.studentId
    GROUP BY s.id, s.firstName, s.lastName;
    
    PRINT 'Complex distributed join test passed!';
END TRY
BEGIN CATCH
    PRINT 'Complex distributed join test failed: ' + ERROR_MESSAGE();
END CATCH

-- Test 4: Performance monitoring
PRINT 'Test 4: Testing performance monitoring...';
EXEC sp_MonitorDistributedQueries;

PRINT 'All distributed query tests completed!';
```

---

**Next Steps:**
1. Ensure all linked servers are properly configured
2. Test each type of distributed query individually
3. Monitor performance using the provided procedures
4. Implement error handling in your production queries
5. Proceed with the distributed transactions script