
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
                    studentId
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

EXEC sp_GetCompleteStudentInfo @StudentId = 1;