
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

EXEC sp_AggregatedReport;