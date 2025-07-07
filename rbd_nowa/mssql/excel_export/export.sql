CREATE OR ALTER PROCEDURE sp_ExportStudentToExcel
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX);

    -- 1. Arkusz Student$
    SET @sql = '
        INSERT INTO OPENROWSET(
            ''Microsoft.ACE.OLEDB.12.0'',
            ''Excel 12.0;Database=C:\excel_exports\StudentData.xlsx;HDR=YES;IMEX=0'',
            ''SELECT id, groupId, firstName, lastName, birthday, genderId FROM [Student$]''
        )
        SELECT id, groupId, firstName, lastName, birthday, genderId
        FROM students
        WHERE id = ' + CAST(@StudentId AS NVARCHAR) + ';
    ';
    EXEC(@sql);

    -- 2. Arkusz ContractsPayments$
    SET @sql = '
        INSERT INTO OPENROWSET(
            ''Microsoft.ACE.OLEDB.12.0'',
            ''Excel 12.0;Database=C:\excel_exports\StudentData.xlsx;HDR=YES;IMEX=0'',
            ''SELECT contractId, studentId, parentId, startDate, endDate, monthlyAmount, paymentId, dueDate, paidDate, amount, status FROM [ContractsPayments$]''
        )
        SELECT
            c.id as contractId,
            c.studentId,
            c.parentId,
            c.startDate,
            c.endDate,
            c.monthlyAmount,
            p.id as paymentId,
            p.dueDate,
            p.paidDate,
            p.amount,
            p.status
        FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS c
        LEFT JOIN ORACLE_FINANCE..FINANCE_DB.PAYMENTS p ON c.id = p.contractId
        WHERE c.studentId = ' + CAST(@StudentId AS NVARCHAR) + ';
    ';
    EXEC(@sql);

    -- 3. Arkusz Remarks$
    DECLARE @pgSql NVARCHAR(MAX);

    SET @pgSql = 
        'SELECT id, studentId, teacherId, value, created_date FROM remarks_main.remark WHERE studentId = ' 
        + CAST(@StudentId AS VARCHAR);

    SET @sql = '
        INSERT INTO OPENROWSET(
            ''Microsoft.ACE.OLEDB.12.0'',
            ''Excel 12.0;Database=C:\excel_exports\StudentData.xlsx;HDR=YES;IMEX=0'',
            ''SELECT id, studentId, teacherId, value, created_date FROM [Remarks$]''
        )
        SELECT 
            id,
            studentId,
            teacherId,
            value,
            created_date
        FROM OPENQUERY(POSTGRES_REMARKS, ''' + REPLACE(@pgSql, '''', '''''') + ''')
    ';

    EXEC(@sql);

    PRINT 'Eksport zakonczony!';
END
GO

EXEC sp_ExportStudentToExcel @StudentId = 1;
