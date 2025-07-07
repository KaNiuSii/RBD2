# Linked Servers Configuration Script

## 1. Configure Linked Server to Oracle

```sql
-- Connect to the main MSSQL server
USE master;
GO

-- Add Oracle linked server
EXEC sp_addlinkedserver 
    @server = 'ORACLE_LINK',
    @srvproduct = 'Oracle',
    @provider = 'OraOLEDB.Oracle',
    @datasrc = 'your_oracle_tnsname';  -- Replace with your Oracle TNS name or connection string
GO

-- Add login mapping for Oracle
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'ORACLE_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'contracts_admin',  -- Oracle username
    @rmtpassword = 'secure_password';  -- Oracle password
GO

-- Configure server options for Oracle
EXEC sp_serveroption 'ORACLE_LINK', 'collation compatible', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'data access', 'true';
EXEC sp_serveroption 'ORACLE_LINK', 'dist', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'pub', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'rpc', 'true';
EXEC sp_serveroption 'ORACLE_LINK', 'rpc out', 'true';
EXEC sp_serveroption 'ORACLE_LINK', 'sub', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'connect timeout', '0';
EXEC sp_serveroption 'ORACLE_LINK', 'collation name', NULL;
EXEC sp_serveroption 'ORACLE_LINK', 'lazy schema validation', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'query timeout', '0';
EXEC sp_serveroption 'ORACLE_LINK', 'use remote collation', 'true';
EXEC sp_serveroption 'ORACLE_LINK', 'remote proc transaction promotion', 'true';
GO

-- Test Oracle connection
SELECT * FROM ORACLE_LINK.contracts_admin.contracts WHERE ROWNUM <= 5;
GO
```

## 2. Configure Linked Server to PostgreSQL

```sql
-- Add PostgreSQL linked server using ODBC
EXEC sp_addlinkedserver 
    @server = 'POSTGRES_LINK',
    @srvproduct = 'PostgreSQL',
    @provider = 'MSDASQL',
    @datasrc = 'PostgreSQL_DSN';  -- Replace with your ODBC DSN name
GO

-- Alternative using direct connection string
/*
EXEC sp_addlinkedserver 
    @server = 'POSTGRES_LINK',
    @srvproduct = 'PostgreSQL',
    @provider = 'MSDASQL',
    @provstr = 'DRIVER={PostgreSQL UNICODE};SERVER=your_postgres_server;PORT=5432;DATABASE=remarks_system;UID=remarks_admin;PWD=secure_password;';
GO
*/

-- Add login mapping for PostgreSQL
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'POSTGRES_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'remarks_admin',  -- PostgreSQL username
    @rmtpassword = 'secure_password';  -- PostgreSQL password
GO

-- Configure server options for PostgreSQL
EXEC sp_serveroption 'POSTGRES_LINK', 'collation compatible', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'data access', 'true';
EXEC sp_serveroption 'POSTGRES_LINK', 'dist', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'pub', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'rpc', 'true';
EXEC sp_serveroption 'POSTGRES_LINK', 'rpc out', 'true';
EXEC sp_serveroption 'POSTGRES_LINK', 'sub', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'connect timeout', '0';
EXEC sp_serveroption 'POSTGRES_LINK', 'collation name', NULL;
EXEC sp_serveroption 'POSTGRES_LINK', 'lazy schema validation', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'query timeout', '0';
EXEC sp_serveroption 'POSTGRES_LINK', 'use remote collation', 'true';
EXEC sp_serveroption 'POSTGRES_LINK', 'remote proc transaction promotion', 'true';
GO

-- Test PostgreSQL connection
SELECT * FROM OPENQUERY(POSTGRES_LINK, 'SELECT * FROM remarks.remark LIMIT 5');
GO
```

## 3. Configure Second MSSQL Server Link

```sql
-- Add second SQL Server linked server
EXEC sp_addlinkedserver 
    @server = 'SQL2',
    @srvproduct = 'SQL Server';
GO

-- Add login mapping for second SQL Server
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'SQL2',
    @useself = 'TRUE';  -- Use current Windows authentication
GO

-- Alternative: Use SQL Server authentication
/*
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'SQL2',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'sql_username',
    @rmtpassword = 'sql_password';
GO
*/

-- Configure server options for second SQL Server
EXEC sp_serveroption 'SQL2', 'collation compatible', 'true';
EXEC sp_serveroption 'SQL2', 'data access', 'true';
EXEC sp_serveroption 'SQL2', 'dist', 'true';
EXEC sp_serveroption 'SQL2', 'pub', 'true';
EXEC sp_serveroption 'SQL2', 'rpc', 'true';
EXEC sp_serveroption 'SQL2', 'rpc out', 'true';
EXEC sp_serveroption 'SQL2', 'sub', 'true';
EXEC sp_serveroption 'SQL2', 'connect timeout', '0';
EXEC sp_serveroption 'SQL2', 'collation name', NULL;
EXEC sp_serveroption 'SQL2', 'lazy schema validation', 'false';
EXEC sp_serveroption 'SQL2', 'query timeout', '0';
EXEC sp_serveroption 'SQL2', 'use remote collation', 'true';
EXEC sp_serveroption 'SQL2', 'remote proc transaction promotion', 'true';
GO

-- Test second SQL Server connection
SELECT * FROM SQL2.SchoolManagement_Replica.dbo.students WHERE id <= 5;
GO
```

## 4. Configure Excel as Data Source

```sql
-- Enable Ad Hoc Distributed Queries (if not already enabled)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- Create Excel linked server
EXEC sp_addlinkedserver 
    @server = 'EXCEL_LINK',
    @srvproduct = 'Excel',
    @provider = 'Microsoft.ACE.OLEDB.12.0',
    @datasrc = 'C:\Data\Analytics.xlsx',  -- Replace with your Excel file path
    @provstr = 'Excel 12.0;HDR=YES;IMEX=1;';
GO

-- No login mapping needed for Excel files
-- Configure server options for Excel
EXEC sp_serveroption 'EXCEL_LINK', 'collation compatible', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'data access', 'true';
EXEC sp_serveroption 'EXCEL_LINK', 'dist', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'pub', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'rpc', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'rpc out', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'sub', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'connect timeout', '0';
EXEC sp_serveroption 'EXCEL_LINK', 'collation name', NULL;
EXEC sp_serveroption 'EXCEL_LINK', 'lazy schema validation', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'query timeout', '0';
EXEC sp_serveroption 'EXCEL_LINK', 'use remote collation', 'true';
GO
```

## 5. Create Distributed Views

```sql
USE SchoolManagement;
GO

-- Create a distributed view combining data from all sources
CREATE VIEW vw_StudentCompleteProfile AS
SELECT 
    -- Student basic information from MSSQL
    s.id AS StudentId,
    s.firstName,
    s.lastName,
    s.birthday,
    g.value AS Gender,
    gr.id AS GroupId,
    y.value AS AcademicYear,
    
    -- Teacher information from MSSQL
    t.firstName + ' ' + t.lastName AS HomeTeacher,
    
    -- Contract information from Oracle
    c.startDate AS ContractStartDate,
    c.endDate AS ContractEndDate,
    c.monthlyAmount AS MonthlyFee,
    
    -- Payment status from Oracle
    p.total_payments,
    p.total_paid,
    p.total_pending,
    
    -- Remarks count from PostgreSQL
    r.total_remarks,
    r.serious_remarks
FROM students s
JOIN genders g ON s.genderId = g.id
JOIN groups gr ON s.groupId = gr.id
JOIN years y ON gr.yearId = y.id
JOIN teachers t ON gr.home_teacher_id = t.id

-- Left join Oracle contract data
LEFT JOIN (
    SELECT 
        studentId,
        startDate,
        endDate,
        monthlyAmount
    FROM ORACLE_LINK..contracts
) c ON s.id = c.studentId

-- Left join Oracle payment summary
LEFT JOIN (
    SELECT 
        ct.studentId,
        COUNT(p.id) AS total_payments,
        SUM(CASE WHEN p.status = 'PAID' THEN 1 ELSE 0 END) AS total_paid,
        SUM(CASE WHEN p.status = 'PENDING' THEN 1 ELSE 0 END) AS total_pending
    FROM ORACLE_LINK..contracts ct
    LEFT JOIN ORACLE_LINK..payments p ON ct.id = p.contractId
    GROUP BY ct.studentId
) p ON s.id = p.studentId

-- Left join PostgreSQL remarks summary
LEFT JOIN (
    SELECT 
        studentId,
        COUNT(*) AS total_remarks,
        SUM(CASE WHEN severity IN ('SERIOUS', 'CRITICAL') THEN 1 ELSE 0 END) AS serious_remarks
    FROM OPENQUERY(POSTGRES_LINK, 'SELECT studentId, severity FROM remarks.remark') 
    GROUP BY studentId
) r ON s.id = r.studentId;
GO

-- Create a view for financial summary from Oracle
CREATE VIEW vw_FinancialSummary AS
SELECT 
    s.id AS StudentId,
    s.firstName + ' ' + s.lastName AS StudentName,
    c.monthlyAmount,
    c.startDate,
    c.endDate,
    DATEDIFF(MONTH, c.startDate, ISNULL(c.endDate, GETDATE())) AS ContractMonths,
    ps.total_due,
    ps.total_paid,
    ps.total_outstanding
FROM students s
JOIN (
    SELECT 
        ct.studentId,
        ct.monthlyAmount,
        ct.startDate,
        ct.endDate,
        SUM(p.amount) AS total_due,
        SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) AS total_paid,
        SUM(CASE WHEN p.status != 'PAID' THEN p.amount ELSE 0 END) AS total_outstanding
    FROM ORACLE_LINK..contracts ct
    LEFT JOIN ORACLE_LINK..payments p ON ct.id = p.contractId
    GROUP BY ct.studentId, ct.monthlyAmount, ct.startDate, ct.endDate
) ps ON s.id = ps.studentId
JOIN ORACLE_LINK..contracts c ON s.id = c.studentId;
GO

-- Create a view for behavioral analysis from PostgreSQL
CREATE VIEW vw_BehavioralSummary AS
SELECT 
    s.id AS StudentId,
    s.firstName + ' ' + s.lastName AS StudentName,
    rs.total_remarks,
    rs.academic_remarks,
    rs.behavioral_remarks,
    rs.attendance_remarks,
    rs.critical_remarks,
    rs.latest_remark_date
FROM students s
LEFT JOIN (
    SELECT 
        studentId,
        COUNT(*) AS total_remarks,
        SUM(CASE WHEN category = 'ACADEMIC' THEN 1 ELSE 0 END) AS academic_remarks,
        SUM(CASE WHEN category = 'BEHAVIORAL' THEN 1 ELSE 0 END) AS behavioral_remarks,
        SUM(CASE WHEN category = 'ATTENDANCE' THEN 1 ELSE 0 END) AS attendance_remarks,
        SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_remarks,
        MAX(created_date) AS latest_remark_date
    FROM OPENQUERY(POSTGRES_LINK, '
        SELECT studentId, category, severity, created_date 
        FROM remarks.remark 
        WHERE created_date >= CURRENT_DATE - INTERVAL ''90 days''
    ')
    GROUP BY studentId
) rs ON s.id = rs.studentId;
GO
```

## 6. Create Stored Procedures for Cross-Database Operations

```sql
-- Procedure to get complete student information from all databases
CREATE PROCEDURE sp_GetStudentCompleteInfo
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Student basic information
    SELECT 
        'Student Information' AS Section,
        s.id,
        s.firstName + ' ' + s.lastName AS FullName,
        s.birthday,
        DATEDIFF(YEAR, s.birthday, GETDATE()) AS Age,
        g.value AS Gender,
        gr.id AS GroupId,
        y.value AS AcademicYear,
        t.firstName + ' ' + t.lastName AS HomeTeacher
    FROM students s
    JOIN genders g ON s.genderId = g.id
    JOIN groups gr ON s.groupId = gr.id
    JOIN years y ON gr.yearId = y.id
    JOIN teachers t ON gr.home_teacher_id = t.id
    WHERE s.id = @StudentId;
    
    -- Contract information from Oracle
    SELECT 
        'Contract Information' AS Section,
        c.startDate,
        c.endDate,
        c.monthlyAmount,
        DATEDIFF(MONTH, c.startDate, ISNULL(c.endDate, GETDATE())) AS ContractDurationMonths
    FROM ORACLE_LINK..contracts c
    WHERE c.studentId = @StudentId;
    
    -- Payment summary from Oracle
    SELECT 
        'Payment Summary' AS Section,
        COUNT(*) AS TotalPayments,
        SUM(CASE WHEN status = 'PAID' THEN 1 ELSE 0 END) AS PaidPayments,
        SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) AS PendingPayments,
        SUM(CASE WHEN status = 'OVERDUE' THEN 1 ELSE 0 END) AS OverduePayments,
        SUM(amount) AS TotalAmount,
        SUM(CASE WHEN status = 'PAID' THEN amount ELSE 0 END) AS PaidAmount,
        SUM(CASE WHEN status != 'PAID' THEN amount ELSE 0 END) AS OutstandingAmount
    FROM ORACLE_LINK..contracts c
    JOIN ORACLE_LINK..payments p ON c.id = p.contractId
    WHERE c.studentId = @StudentId;
    
    -- Recent remarks from PostgreSQL
    SELECT 
        'Recent Remarks' AS Section,
        studentId,
        teacherId,
        value AS RemarkText,
        severity,
        category,
        created_date
    FROM OPENQUERY(POSTGRES_LINK, 'SELECT studentId, teacherId, value, severity, category, created_date FROM remarks.remark WHERE studentId = ' + CAST(@StudentId AS VARCHAR(10)) + ' ORDER BY created_date DESC LIMIT 10');
END;
GO

-- Procedure to synchronize data across databases
CREATE PROCEDURE sp_SynchronizeStudentData
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    
    TRY
        -- Verify student exists in main database
        IF NOT EXISTS (SELECT 1 FROM students WHERE id = @StudentId)
        BEGIN
            RAISERROR('Student with ID %d does not exist in main database', 16, 1, @StudentId);
            RETURN;
        END
        
        -- Get student information
        DECLARE @StudentName NVARCHAR(100);
        SELECT @StudentName = firstName + ' ' + lastName 
        FROM students 
        WHERE id = @StudentId;
        
        -- Log synchronization in remarks system
        DECLARE @RemarkText NVARCHAR(500) = 'Data synchronization performed for student: ' + @StudentName;
        
        EXEC POSTGRES_LINK..pg_proc('remarks.add_remark', @StudentId, 1, @RemarkText, 'INFO', 'GENERAL');
        
        COMMIT TRANSACTION;
        
        PRINT 'Data synchronization completed for student ID: ' + CAST(@StudentId AS VARCHAR(10));
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
```

## 7. Test Linked Server Connections

```sql
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
```

## 8. Create Maintenance Procedures

```sql
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
```

## 9. Security Configuration

```sql
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
```

## 10. Final Validation

```sql
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
```

---

**Next Steps:**
1. Replace all placeholder values with your actual server details
2. Ensure proper network connectivity between servers
3. Install required OLE DB providers for Oracle and PostgreSQL
4. Test each connection individually before proceeding
5. Verify the distributed views return expected data
6. Proceed with the distributed queries script