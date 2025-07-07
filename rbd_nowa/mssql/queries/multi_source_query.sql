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