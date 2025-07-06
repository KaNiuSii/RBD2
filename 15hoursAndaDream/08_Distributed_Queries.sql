
USE SchoolDB;
GO

-- ==========================================
-- AD HOC OPENROWSET
-- ==========================================

-- MSSQL to MSSQL AD HOC query
SELECT 'AD HOC Query - MSSQL to MSSQL:' as QueryType;
SELECT *
FROM OPENROWSET('MSOLEDBSQL',
    'Server=localhost;Trusted_Connection=yes;',
    'SELECT TOP 5 * FROM SchoolDB.dbo.students') AS RemoteStudents;

-- MSSQL to PostgreSQL
SELECT 'AD HOC Query - MSSQL to PostgreSQL:' as QueryType;
SELECT *
FROM OPENROWSET('MSDASQL',
    'DRIVER={PostgreSQL Unicode(x64)};SERVER=localhost;PORT=5432;DATABASE=remarks_system;UID=remarks_user;PWD=Remarks123;',
    'SELECT * FROM remarks_main.remark LIMIT 5') AS PostgresRemarks;

-- MSSQL to PostgreSQL
SELECT 'AD HOC Query - MSSQL to PostgreSQL:' as QueryType;
SELECT *
FROM OPENROWSET('MSDASQL',
    'DRIVER={PostgreSQL Unicode(x64)};SERVER=localhost;PORT=5432;DATABASE=school;UID=remarks_user;PWD=Remarks123;',
    'SELECT * FROM remarks_main.remark LIMIT 5') AS PostgresRemarks;

-- MSSQL to Excel AD HOC query
SELECT 'AD HOC Query - MSSQL to Excel:' as QueryType;
SELECT *
FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\excel_exports\SchoolData.xlsx;HDR=YES',
    'SELECT * FROM [Arkusz1$]') AS ExcelData;

-- ==========================================
-- Multi-source Access Queries
-- ==========================================

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
    FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS
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
    ISNULL(orf.monthlyAmount, 0) as MonthlyFee,
    ISNULL(pr.RemarkCount, 0) as TotalRemarks
FROM StudentBasic sb
    LEFT JOIN OracleFinance orf ON sb.id = orf.studentId
    LEFT JOIN PostgresRemarks pr ON sb.id = pr.studentId
ORDER BY sb.id;

SELECT 'Query to Oracle:' as QueryType;
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

SELECT 'Query to PostgreSQL:' as QueryType;
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
-- Remote Data Modification
-- ==========================================

-- Insert data into Oracle from MSSQL
SELECT 'Remote Data Modification - Insert to Oracle:' as Operation;
INSERT INTO ORACLE_FINANCE..FINANCE_DB.CONTRACTS 
    (studentId, parentId, startDate, endDate, monthlyAmount)
VALUES 
    (11, 1, '2024-01-01', '2024-12-31', 575.00);

-- Update data in Oracle from MSSQL
SELECT 'Remote Data Modification - Update Oracle:' as Operation;
UPDATE ORACLE_FINANCE..FINANCE_DB.PAYMENTS
SET status = 'PAID', paidDate = GETDATE()
WHERE contractId IN (
    SELECT id FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS 
    WHERE studentId = 11
) AND status = 'PENDING';

-- Insert data into PostgreSQL from MSSQL
SELECT 'Remote Data Modification - Insert to PostgreSQL:' as Operation;
SELECT * FROM OPENQUERY(POSTGRES_REMARKS, 'INSERT INTO remarks_main.remark (studentId, teacherId, value) 
            VALUES (11, 1, ''Student transferred from another system - good academic record'')');

-- ==========================================
-- Distributed Views and Procedures
-- ==========================================

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
        FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS
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
            FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS c
                LEFT JOIN ORACLE_FINANCE..FINANCE_DB.PAYMENTS p ON c.id = p.contractId
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
-- Aggregation Function
-- ==========================================

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
