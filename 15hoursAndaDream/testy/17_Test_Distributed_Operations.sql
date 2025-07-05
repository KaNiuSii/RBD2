USE SchoolDB;
GO

-- Test 1: Linked server connectivity
BEGIN TRY
    SELECT 'Oracle connection test' as TestType;
    SELECT COUNT(*) as RecordCount FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS;
    SELECT 'Oracle linked server: CONNECTED';
END TRY
BEGIN CATCH
    PRINT 'Oracle linked server: FAILED - ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT 'PostgreSQL connection test' as TestType;
    SELECT * FROM OPENQUERY(POSTGRES_REMARKS, 'SELECT COUNT(*) as remark_count FROM remarks_main.remark');
    SELECT 'PostgreSQL linked server: CONNECTED';
END TRY
BEGIN CATCH
    PRINT 'PostgreSQL linked server: FAILED - ' + ERROR_MESSAGE();
END CATCH;

-- Test 2: Distributed views
SELECT TOP 10 * FROM vw_StudentCompleteInfo;
SELECT TOP 10 * FROM vw_StudentFinancialInfo;
SELECT TOP 10 * FROM vw_DistributedStudentData;

-- Test 3: Cross-database queries
SELECT 
    s.firstName + ' ' + s.lastName as StudentName,
    oracle_finance.MonthlyAmount,
    postgres_remarks.RemarkCount
FROM students s
LEFT JOIN (
    SELECT 
        studentId,
        monthlyAmount as MonthlyAmount
    FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS
) oracle_finance ON s.id = oracle_finance.studentId
LEFT JOIN (
    SELECT 
        studentId,
        RemarkCount
    FROM OPENQUERY(POSTGRES_REMARKS, 
        'SELECT studentId, COUNT(*) as RemarkCount 
         FROM remarks_main.remark 
         GROUP BY studentId')
) postgres_remarks ON s.id = postgres_remarks.studentId
WHERE s.id <= 10;

-- Test 4: Distributed stored procedures
EXEC sp_GetCompleteStudentInfo @StudentId = 1;
EXEC sp_DistributedStudentReport @StartDate = '2024-01-01', @EndDate = '2024-12-31';

-- Test 5: Aggregated reports
EXEC sp_AggregatedReport;

-- Test 6: Ad-hoc distributed queries
SELECT 'Multi-source student data' as QueryType;
WITH StudentData AS (
    SELECT 
        s.id,
        s.firstName + ' ' + s.lastName as FullName,
        s.birthday
    FROM students s
    WHERE s.id <= 5
),
FinanceData AS (
    SELECT 
        c.studentId,
        c.monthlyAmount,
        COUNT(p.id) as PaymentCount
    FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS c
    LEFT JOIN ORACLE_FINANCE..FINANCE_DB.PAYMENTS p ON c.id = p.contractId
    GROUP BY c.studentId, c.monthlyAmount
),
RemarkData AS (
    SELECT 
        studentId,
        RemarkCount
    FROM OPENQUERY(POSTGRES_REMARKS, 
        'SELECT studentId, COUNT(*) as RemarkCount 
         FROM remarks_main.remark 
         GROUP BY studentId')
)
SELECT 
    sd.id,
    sd.FullName,
    sd.birthday,
    ISNULL(fd.monthlyAmount, 0) as MonthlyFee,
    ISNULL(fd.PaymentCount, 0) as TotalPayments,
    ISNULL(rd.RemarkCount, 0) as TotalRemarks
FROM StudentData sd
LEFT JOIN FinanceData fd ON sd.id = fd.studentId
LEFT JOIN RemarkData rd ON sd.id = rd.studentId;

-- Test 7: Data modification across systems

EXEC sp_serveroption 'POSTGRES_REMARKS', 'rpc', true;
EXEC sp_serveroption 'POSTGRES_REMARKS', 'rpc out', true;
EXEC sp_serveroption 'POSTGRES_REMARKS', 'collation compatible', true;

BEGIN TRY
    -- Insert test student
    INSERT INTO students (groupId, firstName, lastName, birthday, genderId)
    VALUES (1, 'DistTest2', 'Student2', '2011-01-01', 1);

    DECLARE @TestStudentId INT = SCOPE_IDENTITY();
    PRINT 'Created test student with ID: ' + CAST(@TestStudentId AS VARCHAR(10));

    -- Add financial record in Oracle
    INSERT INTO ORACLE_FINANCE..FINANCE_DB.CONTRACTS
    (studentId, parentId, startDate, endDate, monthlyAmount)
    VALUES 
    (@TestStudentId, 1, GETDATE(), DATEADD(YEAR, 1, GETDATE()), 500);

    PRINT 'Added financial record in Oracle';

    -- Add remark in PostgreSQL via RPC
    DECLARE @RPC_SQL NVARCHAR(MAX) = 
        'INSERT INTO remarks_main.remark (studentId, teacherId, value) VALUES (' +
        CAST(@TestStudentId AS VARCHAR(10)) + ', 1, ''Test remark from distributed operation'')';

    EXEC (@RPC_SQL) AT POSTGRES_REMARKS;


END TRY
BEGIN CATCH
    PRINT 'Distributed data modification failed: ' + ERROR_MESSAGE();
END CATCH;

-- Test 8: Performance analysis
DECLARE @StartTime DATETIME = GETDATE();

-- Local query performance
SELECT COUNT(*) as LocalStudentCount FROM students;
DECLARE @LocalTime DATETIME = GETDATE();

-- Remote Oracle query performance
SELECT COUNT(*) as OracleContractCount FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS;
DECLARE @OracleTime DATETIME = GETDATE();

-- Remote PostgreSQL query performance
SELECT * FROM OPENQUERY(POSTGRES_REMARKS, 'SELECT COUNT(*) as postgres_remark_count FROM remarks_main.remark');
DECLARE @PostgresTime DATETIME = GETDATE();

SELECT 
    'Performance Analysis' as TestType,
    DATEDIFF(MILLISECOND, @StartTime, @LocalTime) as LocalQueryTime_ms,
    DATEDIFF(MILLISECOND, @LocalTime, @OracleTime) as OracleQueryTime_ms,
    DATEDIFF(MILLISECOND, @OracleTime, @PostgresTime) as PostgresQueryTime_ms,
    DATEDIFF(MILLISECOND, @StartTime, @PostgresTime) as TotalTime_ms;

