
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

DECLARE @Today DATE = GETDATE();
DECLARE @ThreeMonthsAgo DATE = DATEADD(MONTH, -3, @Today);

EXEC sp_DistributedStudentReport 
    @StartDate = @ThreeMonthsAgo, 
    @EndDate = @Today;