
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

SELECT * FROM vw_DistributedStudentData;