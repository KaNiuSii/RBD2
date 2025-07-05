
USE master;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- ==========================================
-- Configure linked server to Oracle
-- ==========================================

IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'ORACLE_FINANCE')
    EXEC master.dbo.sp_dropserver @server=N'ORACLE_FINANCE', @droplogins='droplogins';
GO

EXEC master.dbo.sp_addlinkedserver 
    @server = N'ORACLE_FINANCE',
    @srvproduct = N'Oracle',
    @provider = N'OraOLEDB.Oracle',
    @datasrc = N'127.0.0.1:1521/PD19C';
GO

EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = N'ORACLE_FINANCE',
    @useself = N'False',
    @locallogin = NULL,
    @rmtuser = N'FINANCE_DB',
    @rmtpassword = N'Finance123';
GO

SELECT * FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS

-- ==========================================
-- Configure linked server to PostgreSQL
-- ==========================================

IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'POSTGRES_REMARKS')
    EXEC master.dbo.sp_dropserver @server=N'POSTGRES_REMARKS', @droplogins='droplogins';
GO

EXEC master.dbo.sp_addlinkedserver 
    @server = N'POSTGRES_REMARKS',
    @srvproduct = N'PostgreSQL',
    @provider = N'MSDASQL',
    @datasrc  = N'PostgreSQL30'; 
GO

EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = N'POSTGRES_REMARKS',
    @useself = N'False',
    @locallogin = NULL,
    @rmtuser = N'remarks_user',
    @rmtpassword = N'Remarks123';
GO

SELECT * FROM [POSTGRES_REMARKS].[remarks_system].[remarks_main].[remark]
SELECT * FROM [POSTGRES_REMARKS].[school].[remarks_main].[remark]

-- ==========================================
-- Configure linked server to another MSSQL (for replication)
-- ==========================================

IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'MSSQL_REPLICA')
    EXEC master.dbo.sp_dropserver @server=N'MSSQL_REPLICA', @droplogins='droplogins';
GO

EXEC master.dbo.sp_addlinkedserver 
    @server = N'MSSQL_REPLICA',
    @srvproduct = N'',  
    @provider   = N'MSOLEDBSQL',
    @datasrc    = N'127.0.0.1,1434';      
GO

EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = N'MSSQL_REPLICA',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'sa',
    @rmtpassword = 'Str0ng!Passw0rd';
GO

-- ==========================================
-- Configure linked server to Excel 
-- ==========================================

IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'EXCEL_DATA')
    EXEC master.dbo.sp_dropserver @server=N'EXCEL_DATA', @droplogins='droplogins';
GO

EXEC master.dbo.sp_addlinkedserver 
    @server = N'EXCEL_DATA',
    @srvproduct = N'Excel',
    @provider = N'Microsoft.ACE.OLEDB.12.0',
    @datasrc = N'C:\excel_exports\SchoolData.xlsx',
    @provstr = N'Excel 12.0;HDR=YES;';
GO

-- ==========================================
-- Test linked server connections
-- ==========================================

BEGIN TRY
    SELECT 'Oracle connection test:' as Test;
    SELECT TOP 5 * FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS;
    PRINT 'Oracle linked server connection successful!';
END TRY
BEGIN CATCH
    PRINT 'Oracle linked server connection failed: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT 'PostgreSQL connection test:' as Test;
    SELECT * FROM OPENQUERY(POSTGRES_REMARKS, 'SELECT COUNT(*) as remark_count FROM remarks_main.remark');
    PRINT 'PostgreSQL linked server connection successful!';
END TRY
BEGIN CATCH
    PRINT 'PostgreSQL linked server connection failed: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT 'MSSQL Replica connection test:' as Test;
    SELECT @@SERVERNAME as LocalServer, LinkedServer.ServerName as RemoteServer
    FROM OPENQUERY(MSSQL_REPLICA, 'SELECT @@SERVERNAME as ServerName') LinkedServer;
    PRINT 'MSSQL replica linked server connection successful!';
END TRY
BEGIN CATCH
    PRINT 'MSSQL replica linked server connection failed: ' + ERROR_MESSAGE();
END CATCH;

-- ==========================================
-- Create distributed views
-- ==========================================

USE SchoolDB;
GO

CREATE OR ALTER VIEW vw_StudentCompleteInfo AS
SELECT 
    s.id as StudentId,
    s.firstName + ' ' + s.lastName as StudentName,
    s.birthday,
    g.value as Gender,
    y.value as SchoolYear,
    p.firstName + ' ' + p.lastName as ParentName,
    p.email as ParentEmail,
    p.phoneNumber as ParentPhone
FROM students s
    INNER JOIN genders g ON s.genderId = g.id
    INNER JOIN groups gr ON s.groupId = gr.id
    INNER JOIN years y ON gr.yearId = y.id
    INNER JOIN parents_students ps ON s.id = ps.studentId
    INNER JOIN parents p ON ps.parentId = p.id;
GO

CREATE OR ALTER VIEW vw_StudentFinancialInfo AS
SELECT 
    s.id as StudentId,
    s.firstName + ' ' + s.lastName as StudentName,
    ISNULL(oracle_data.monthlyAmount, 0) as MonthlyAmount,
    ISNULL(oracle_data.totalPaid, 0) as TotalPaid,
    ISNULL(oracle_data.pendingAmount, 0) as PendingAmount
FROM students s
    LEFT JOIN (
        SELECT 
            c.studentId,
            c.monthlyAmount,
            ISNULL(p.totalPaid, 0) as totalPaid,
            ISNULL(c.monthlyAmount * 12 - p.totalPaid, c.monthlyAmount * 12) as pendingAmount
        FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS c
            LEFT JOIN (
                SELECT 
                    contractId,
                    SUM(CASE WHEN status = 'PAID' THEN amount ELSE 0 END) as totalPaid
                FROM ORACLE_FINANCE..FINANCE_DB.PAYMENTS
                GROUP BY contractId
            ) p ON c.id = p.contractId
    ) oracle_data ON s.id = oracle_data.studentId;
GO

-- ==========================================
-- Create stored procedures for distributed operations
-- ==========================================

CREATE OR ALTER PROCEDURE sp_GetCompleteStudentInfo
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.id,
        s.firstName,
        s.lastName,
        s.birthday,
        g.value as gender,
        y.value as schoolYear
    FROM students s
        INNER JOIN genders g ON s.genderId = g.id
        INNER JOIN groups gr ON s.groupId = gr.id
        INNER JOIN years y ON gr.yearId = y.id
    WHERE s.id = @StudentId;

    BEGIN TRY
        SELECT 
            c.monthlyAmount,
            c.startDate,
            c.endDate,
            COUNT(p.id) as totalPayments,
            SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) as totalPaid
        FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS c
            LEFT JOIN ORACLE_FINANCE..FINANCE_DB.PAYMENTS p ON c.id = p.contractId
        WHERE c.studentId = @StudentId
        GROUP BY c.monthlyAmount, c.startDate, c.endDate;
    END TRY
    BEGIN CATCH
        SELECT 'Financial data unavailable' as Error;
    END CATCH;

    BEGIN TRY
    SELECT  teacherId,
            remark,
            created_date
    FROM    OPENQUERY(POSTGRES_REMARKS,
            'SELECT teacherId,
                    value      AS remark,
                    created_date,
                    studentId  -- musi być zwrócone!
             FROM   remarks_main.remark'
            ) AS rq
    WHERE   rq.studentId = @StudentId;

	END TRY
	BEGIN CATCH
		SELECT 'Remarks data unavailable' AS Error,
			   ERROR_NUMBER()             AS ErrNo,
			   ERROR_MESSAGE()            AS ErrMsg;
	END CATCH;
END;
GO
