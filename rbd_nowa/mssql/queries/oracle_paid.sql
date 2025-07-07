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