
-- ==========================================
-- Distributed Queries and Operations Script
-- AD HOC Queries and Remote Data Access
-- ==========================================

USE SchoolDB;
GO

-- ==========================================
-- SECTION 1: AD HOC Queries using OPENROWSET
-- ==========================================

-- Example 1: MSSQL to MSSQL AD HOC query
SELECT 'AD HOC Query - MSSQL to MSSQL:' as QueryType;
SELECT *
FROM OPENROWSET('MSOLEDBSQL',
    'Server=localhost;Trusted_Connection=yes;',
    'SELECT TOP 5 * FROM SchoolDB.dbo.students') AS RemoteStudents;

-- Example 2: MSSQL to Oracle AD HOC query
SELECT 'AD HOC Query - MSSQL to Oracle:' as QueryType;
SELECT *
FROM OPENROWSET('OraOLEDB.Oracle',
    'localhost:1521/XE;FINANCE_DB;Finance123',
    'SELECT * FROM contracts WHERE ROWNUM <= 5') AS OracleContracts;

-- Example 3: MSSQL to PostgreSQL AD HOC query (requires ODBC)
SELECT 'AD HOC Query - MSSQL to PostgreSQL:' as QueryType;
-- Note: This requires proper ODBC driver configuration
SELECT *
FROM OPENROWSET('MSDASQL',
    'DRIVER={PostgreSQL ODBC Driver(UNICODE)};SERVER=localhost;PORT=5432;DATABASE=remarksdb;UID=remarks_user;PWD=Remarks123;',
    'SELECT * FROM remarks_main.remark LIMIT 5') AS PostgresRemarks;

-- Example 4: MSSQL to Excel AD HOC query
SELECT 'AD HOC Query - MSSQL to Excel:' as QueryType;
SELECT *
FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\StudentGrades.xlsx;HDR=YES',
    'SELECT * FROM [Sheet1$]') AS ExcelData;

-- ==========================================
-- SECTION 2: Multi-source Access Queries
-- ==========================================

-- Example 5: Query combining data from MSSQL, Oracle, and PostgreSQL
SELECT 'Multi-source Query:' as QueryType;
WITH StudentBasic AS (
    SELECT 
        id,
        firstName + ' ' + lastName as FullName,
        birthday,
        groupId
    FROM students
),
OracleFinance AS (
    SELECT 
        studentId,
        monthlyAmount,
        startDate as ContractStart
    FROM ORACLE_FINANCE.FINANCE_DB.CONTRACTS
),
PostgresRemarks AS (
    SELECT * FROM OPENQUERY(POSTGRES_REMARKS,
        'SELECT studentId, COUNT(*) as RemarkCount 
         FROM remarks_main.remark 
         GROUP BY studentId')
)
SELECT 
    sb.id,
    sb.FullName,
    sb.birthday,
    ISNULL(of.monthlyAmount, 0) as MonthlyFee,
    ISNULL(pr.RemarkCount, 0) as TotalRemarks
FROM StudentBasic sb
    LEFT JOIN OracleFinance of ON sb.id = of.studentId
    LEFT JOIN PostgresRemarks pr ON sb.id = pr.studentId
ORDER BY sb.id;

-- ==========================================
-- SECTION 3: Pass-through Queries using OPENQUERY
-- ==========================================

-- Example 6: Pass-through query to Oracle
SELECT 'Pass-through Query to Oracle:' as QueryType;
SELECT *
FROM OPENQUERY(ORACLE_FINANCE,
    'SELECT 
        c.studentId,
        c.monthlyAmount,
        COUNT(p.id) as PaymentCount,
        SUM(CASE WHEN p.status = ''PAID'' THEN p.amount ELSE 0 END) as TotalPaid
     FROM contracts c
        LEFT JOIN payments p ON c.id = p.contractId
     GROUP BY c.studentId, c.monthlyAmount') AS OracleFinanceData;

-- Example 7: Pass-through query to PostgreSQL
SELECT 'Pass-through Query to PostgreSQL:' as QueryType;
SELECT *
FROM OPENQUERY(POSTGRES_REMARKS,
    'SELECT 
        r.studentId,
        r.teacherId,
        COUNT(*) as RemarkCount,
        MAX(r.created_date) as LastRemarkDate
     FROM remarks_main.remark r
     GROUP BY r.studentId, r.teacherId
     ORDER BY r.studentId, r.teacherId') AS PostgresRemarksData;

-- ==========================================
-- SECTION 4: Remote Data Modification
-- ==========================================

-- Example 8: Insert data into Oracle from MSSQL
SELECT 'Remote Data Modification - Insert to Oracle:' as Operation;
INSERT INTO ORACLE_FINANCE.FINANCE_DB.CONTRACTS 
    (studentId, parentId, startDate, endDate, monthlyAmount)
VALUES 
    (11, 1, '2024-01-01', '2024-12-31', 575.00);

-- Example 9: Update data in Oracle from MSSQL
SELECT 'Remote Data Modification - Update Oracle:' as Operation;
UPDATE ORACLE_FINANCE.FINANCE_DB.PAYMENTS
SET status = 'PAID', paidDate = GETDATE()
WHERE contractId IN (
    SELECT id FROM ORACLE_FINANCE.FINANCE_DB.CONTRACTS 
    WHERE studentId = 11
) AND status = 'PENDING';

-- Example 10: Insert data into PostgreSQL from MSSQL (using OPENQUERY)
SELECT 'Remote Data Modification - Insert to PostgreSQL:' as Operation;
DECLARE @sql NVARCHAR(MAX);
SET @sql = 'INSERT INTO remarks_main.remark (studentId, teacherId, value) 
            VALUES (11, 1, ''Student transferred from another system - good academic record'')';
SELECT * FROM OPENQUERY(POSTGRES_REMARKS, @sql);

-- ==========================================
-- SECTION 5: Distributed Views and Procedures
-- ==========================================

-- Create a distributed view with data type casting
CREATE OR ALTER VIEW vw_DistributedStudentData AS
SELECT 
    CAST(s.id AS INT) as StudentId,
    CAST(s.firstName + ' ' + s.lastName AS NVARCHAR(200)) as StudentName,
    CAST(s.birthday AS DATE) as BirthDate,
    CAST(oracle_data.monthlyAmount AS DECIMAL(10,2)) as MonthlyAmount,
    CAST(postgres_data.RemarkCount AS INT) as RemarkCount
FROM students s
    LEFT JOIN (
        SELECT 
            CAST(studentId AS INT) as studentId,
            CAST(monthlyAmount AS DECIMAL(10,2)) as monthlyAmount
        FROM ORACLE_FINANCE.FINANCE_DB.CONTRACTS
    ) oracle_data ON s.id = oracle_data.studentId
    LEFT JOIN (
        SELECT 
            studentId,
            RemarkCount
        FROM OPENQUERY(POSTGRES_REMARKS,
            'SELECT studentId, COUNT(*) as RemarkCount 
             FROM remarks_main.remark 
             GROUP BY studentId')
    ) postgres_data ON s.id = postgres_data.studentId;
GO

-- Create a stored procedure for distributed operations
CREATE OR ALTER PROCEDURE sp_DistributedStudentReport
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartDateStr VARCHAR(20) = ISNULL(CONVERT(VARCHAR(20), @StartDate, 120), '2024-01-01');
    DECLARE @EndDateStr VARCHAR(20) = ISNULL(CONVERT(VARCHAR(20), @EndDate, 120), '2024-12-31');

    -- Get students with financial and remark data
    SELECT 
        s.id,
        s.firstName + ' ' + s.lastName as StudentName,
        ISNULL(finance.TotalDue, 0) as TotalFinancialDue,
        ISNULL(finance.TotalPaid, 0) as TotalFinancialPaid,
        ISNULL(remarks.RemarkCount, 0) as TotalRemarks,
        ISNULL(attendance.AttendanceRate, 0) as AttendanceRate
    FROM students s
        LEFT JOIN (
            -- Financial data from Oracle
            SELECT 
                c.studentId,
                c.monthlyAmount * 12 as TotalDue,
                SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) as TotalPaid
            FROM ORACLE_FINANCE.FINANCE_DB.CONTRACTS c
                LEFT JOIN ORACLE_FINANCE.FINANCE_DB.PAYMENTS p ON c.id = p.contractId
            GROUP BY c.studentId, c.monthlyAmount
        ) finance ON s.id = finance.studentId
        LEFT JOIN (
            -- Remarks data from PostgreSQL
            SELECT 
                studentId,
                RemarkCount
            FROM OPENQUERY(POSTGRES_REMARKS,
                'SELECT studentId, COUNT(*) as RemarkCount 
                 FROM remarks_main.remark 
                 GROUP BY studentId')
        ) remarks ON s.id = remarks.studentId
        LEFT JOIN (
            -- Attendance data from local MSSQL
            SELECT 
                ats.studentId,
                CAST(AVG(CAST(ats.present AS FLOAT)) * 100 AS DECIMAL(5,2)) as AttendanceRate
            FROM attendance_student ats
                INNER JOIN attendances a ON ats.attendanceId = a.id
            WHERE a.dateTimeChecked BETWEEN @StartDate AND @EndDate
            GROUP BY ats.studentId
        ) attendance ON s.id = attendance.studentId
    ORDER BY s.id;
END;
GO

-- ==========================================
-- SECTION 6: Functions for Remote Data Verification
-- ==========================================

-- Function to verify remote data sources
CREATE OR ALTER FUNCTION fn_VerifyRemoteConnections()
RETURNS TABLE
AS
RETURN
(
    SELECT 
        'Oracle' as DataSource,
        CASE 
            WHEN EXISTS (SELECT 1 FROM ORACLE_FINANCE.FINANCE_DB.CONTRACTS) 
            THEN 'Connected' 
            ELSE 'Failed' 
        END as Status
    UNION ALL
    SELECT 
        'PostgreSQL' as DataSource,
        CASE 
            WHEN EXISTS (
                SELECT * FROM OPENQUERY(POSTGRES_REMARKS, 'SELECT 1 as test')
            ) 
            THEN 'Connected' 
            ELSE 'Failed' 
        END as Status
);
GO

-- ==========================================
-- SECTION 7: Aggregation Functions (Local and Remote)
-- ==========================================

-- Local aggregation with remote data
CREATE OR ALTER PROCEDURE sp_AggregatedReport
AS
BEGIN
    SET NOCOUNT ON;

    -- Local student count by group
    SELECT 'Local Student Statistics:' as ReportSection;
    SELECT 
        g.id as GroupId,
        COUNT(s.id) as StudentCount,
        AVG(DATEDIFF(YEAR, s.birthday, GETDATE())) as AverageAge
    FROM groups g
        LEFT JOIN students s ON g.id = s.groupId
    GROUP BY g.id
    ORDER BY g.id;

    -- Remote financial aggregation
    SELECT 'Remote Financial Statistics:' as ReportSection;
    SELECT *
    FROM OPENQUERY(ORACLE_FINANCE,
        'SELECT 
            COUNT(c.id) as TotalContracts,
            AVG(c.monthlyAmount) as AverageMonthlyAmount,
            SUM(CASE WHEN p.status = ''PAID'' THEN p.amount ELSE 0 END) as TotalPaidAmount,
            COUNT(CASE WHEN p.status = ''PENDING'' THEN 1 END) as PendingPayments
         FROM contracts c
            LEFT JOIN payments p ON c.id = p.contractId');

    -- Remote remarks aggregation
    SELECT 'Remote Remarks Statistics:' as ReportSection;
    SELECT *
    FROM OPENQUERY(POSTGRES_REMARKS,
        'SELECT 
            COUNT(*) as TotalRemarks,
            COUNT(DISTINCT studentId) as StudentsWithRemarks,
            COUNT(DISTINCT teacherId) as TeachersGivingRemarks
         FROM remarks_main.remark');
END;
GO

PRINT 'Distributed queries and operations script completed successfully!';
PRINT 'Test the procedures and views to ensure proper connectivity to remote data sources.';
