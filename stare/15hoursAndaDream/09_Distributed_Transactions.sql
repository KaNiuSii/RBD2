
USE SchoolDB;
GO

SELECT 'DTC Configuration Check:' as Section;
SELECT 
    name,
    value,
    value_in_use,
    description
FROM sys.configurations
WHERE name IN ('remote proc trans', 'distributed transactions');

-- ==========================================
-- Distributed Transaction
-- ==========================================

CREATE OR ALTER PROCEDURE sp_DistributedTransactionExample1
    @StudentId INT,
    @ParentId INT,
    @MonthlyAmount DECIMAL(10,2),
    @RemarkText NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN DISTRIBUTED TRANSACTION;

    BEGIN TRY
        --  Insert new student in local MSSQL database
        INSERT INTO students (groupId, firstName, lastName, birthday, genderId)
        VALUES (1, 'New', 'Student', '2010-01-01', 1);

        DECLARE @NewStudentId INT = SCOPE_IDENTITY();

        --  Create contract in Oracle database
        INSERT INTO ORACLE_FINANCE..FINANCE_DB.CONTRACTS 
            (studentId, parentId, startDate, endDate, monthlyAmount)
        VALUES 
            (@NewStudentId, @ParentId, GETDATE(), DATEADD(YEAR, 1, GETDATE()), @MonthlyAmount);

        --  Add initial remark in PostgreSQL (simulated)
        DECLARE @PostgresSQL NVARCHAR(MAX);
        SET @PostgresSQL = 'INSERT INTO remarks_main.remark (studentId, teacherId, value) VALUES (' 
            + CAST(@NewStudentId AS VARCHAR(10)) + ', 1, ' + CHAR(39) + @RemarkText + CHAR(39) + ')';

        -- Execute PostgreSQL insert via OPENQUERY
        DECLARE @ExecSQL NVARCHAR(MAX);
        SET @ExecSQL = 'SELECT * FROM OPENQUERY(POSTGRES_REMARKS, ' + CHAR(39) + @PostgresSQL + CHAR(39) + ')';
        EXEC sp_executesql @ExecSQL;

        -- If all operations succeed, commit the distributed transaction
        COMMIT TRANSACTION;

        SELECT 'Distributed transaction completed successfully!' as Result;
        SELECT @NewStudentId as NewStudentId;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            'Distributed transaction failed!' as Result,
            ERROR_MESSAGE() as ErrorMessage,
            ERROR_NUMBER() as ErrorNumber;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE sp_ComplexDistributedTransaction
    @StudentId INT,
    @PaymentAmount DECIMAL(10,2),
    @AttendanceDate DATETIME,
    @Present BIT,
    @RemarkText NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN DISTRIBUTED TRANSACTION;

    BEGIN TRY
        -- Record payment in Oracle
        DECLARE @ContractId INT;
        SELECT @ContractId = id FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS WHERE studentId = @StudentId;

        IF @ContractId IS NOT NULL
        BEGIN
            INSERT INTO ORACLE_FINANCE..FINANCE_DB.PAYMENTS 
                (contractId, dueDate, paidDate, amount, status)
            VALUES 
                (@ContractId, @AttendanceDate, @AttendanceDate, @PaymentAmount, 'PAID');
        END;

        --  Record attendance in local MSSQL
        DECLARE @LessonId INT = 1;

        -- Insert attendance record
        INSERT INTO attendances (dateTimeChecked, lessonId)
        VALUES (@AttendanceDate, @LessonId);

        DECLARE @AttendanceId INT = SCOPE_IDENTITY();

        -- Insert student attendance
        INSERT INTO attendance_student (attendanceId, studentId, present)
        VALUES (@AttendanceId, @StudentId, @Present);

        --  Add remark in PostgreSQL
        DECLARE @PostgresSQL NVARCHAR(MAX);
        SET @PostgresSQL = 'INSERT INTO remarks_main.remark (studentId, teacherId, value) VALUES (' 
            + CAST(@StudentId AS VARCHAR(10)) + ', 1, ' + CHAR(39) + @RemarkText + CHAR(39) + ')';

        DECLARE @ExecSQL NVARCHAR(MAX);
        SET @ExecSQL = 'SELECT * FROM OPENQUERY(POSTGRES_REMARKS, ' + CHAR(39) + @PostgresSQL + CHAR(39) + ')';
        EXEC sp_executesql @ExecSQL;

        --  Update student record locally
        UPDATE students 
        SET lastName = lastName + ' (Updated via Distributed Transaction)'
        WHERE id = @StudentId;

        COMMIT TRANSACTION;

        SELECT 'Complex distributed transaction completed successfully!' as Result;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT 
            'Complex distributed transaction failed!' as Result,
            ERROR_MESSAGE() as ErrorMessage,
            ERROR_NUMBER() as ErrorNumber;
    END CATCH;
END;
GO
