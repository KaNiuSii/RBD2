USE SchoolDB;
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

SELECT * FROM vw_StudentFinancialInfo;