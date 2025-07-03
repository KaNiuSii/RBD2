
-- ==========================================
-- Distributed Transactions Script
-- MS DTC Configuration and Examples
-- ==========================================

USE SchoolDB;
GO

-- ==========================================
-- SECTION 1: MS DTC Configuration Verification
-- ==========================================

-- Check if DTC is properly configured
SELECT 'DTC Configuration Check:' as Section;
SELECT 
    name,
    value,
    value_in_use,
    description
FROM sys.configurations
WHERE name IN ('remote proc trans', 'distributed transactions');

-- Function to check DTC service status (simulation)
CREATE OR ALTER FUNCTION fn_CheckDTCStatus()
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @Status VARCHAR(MAX) = '';

    -- In a real environment, you would check the actual DTC service
    -- This is a simulation for demonstration purposes
    IF EXISTS (SELECT * FROM sys.configurations WHERE name = 'remote proc trans' AND value_in_use = 1)
        SET @Status = @Status + 'Remote Procedure Transactions: Enabled' + CHAR(13) + CHAR(10);
    ELSE
        SET @Status = @Status + 'Remote Procedure Transactions: Disabled' + CHAR(13) + CHAR(10);

    SET @Status = @Status + 'DTC Service: Should be running on all participating servers' + CHAR(13) + CHAR(10);
    SET @Status = @Status + 'Network DTC Access: Should be enabled' + CHAR(13) + CHAR(10);
    SET @Status = @Status + 'Authentication: Configured for distributed transactions' + CHAR(13) + CHAR(10);

    RETURN @Status;
END;
GO

-- Display DTC configuration status
SELECT dbo.fn_CheckDTCStatus() as DTCConfigurationStatus;

-- ==========================================
-- SECTION 2: Distributed Transaction Examples
-- ==========================================

-- Example 1: Simple distributed transaction across MSSQL and Oracle
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
        -- Step 1: Insert new student in local MSSQL database
        INSERT INTO students (groupId, firstName, lastName, birthday, genderId)
        VALUES (1, 'New', 'Student', '2010-01-01', 1);

        DECLARE @NewStudentId INT = SCOPE_IDENTITY();

        -- Step 2: Create contract in Oracle database
        INSERT INTO ORACLE_FINANCE..FINANCE_DB.CONTRACTS 
            (studentId, parentId, startDate, endDate, monthlyAmount)
        VALUES 
            (@NewStudentId, @ParentId, GETDATE(), DATEADD(YEAR, 1, GETDATE()), @MonthlyAmount);

        -- Step 3: Add initial remark in PostgreSQL (simulated)
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
        -- If any operation fails, rollback the entire distributed transaction
        ROLLBACK TRANSACTION;

        SELECT 
            'Distributed transaction failed!' as Result,
            ERROR_MESSAGE() as ErrorMessage,
            ERROR_NUMBER() as ErrorNumber;
    END CATCH;
END;
GO

-- Example 2: Complex distributed transaction with multiple operations
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
        -- Step 1: Record payment in Oracle
        DECLARE @ContractId INT;
        SELECT @ContractId = id FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS WHERE studentId = @StudentId;

        IF @ContractId IS NOT NULL
        BEGIN
            INSERT INTO ORACLE_FINANCE..FINANCE_DB.PAYMENTS 
                (contractId, dueDate, paidDate, amount, status)
            VALUES 
                (@ContractId, @AttendanceDate, @AttendanceDate, @PaymentAmount, 'PAID');
        END;

        -- Step 2: Record attendance in local MSSQL
        DECLARE @LessonId INT = 1; -- Assume lesson ID 1 for example

        -- Insert attendance record
        INSERT INTO attendances (dateTimeChecked, lessonId)
        VALUES (@AttendanceDate, @LessonId);

        DECLARE @AttendanceId INT = SCOPE_IDENTITY();

        -- Insert student attendance
        INSERT INTO attendance_student (attendanceId, studentId, present)
        VALUES (@AttendanceId, @StudentId, @Present);

        -- Step 3: Add remark in PostgreSQL
        DECLARE @PostgresSQL NVARCHAR(MAX);
        SET @PostgresSQL = 'INSERT INTO remarks_main.remark (studentId, teacherId, value) VALUES (' 
            + CAST(@StudentId AS VARCHAR(10)) + ', 1, ' + CHAR(39) + @RemarkText + CHAR(39) + ')';

        DECLARE @ExecSQL NVARCHAR(MAX);
        SET @ExecSQL = 'SELECT * FROM OPENQUERY(POSTGRES_REMARKS, ' + CHAR(39) + @PostgresSQL + CHAR(39) + ')';
        EXEC sp_executesql @ExecSQL;

        -- Step 4: Update student record locally
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

-- ==========================================
-- SECTION 3: Transaction Monitoring and Logging
-- ==========================================

-- Create a table to log distributed transactions
CREATE TABLE DistributedTransactionLog (
    LogId INT IDENTITY(1,1) PRIMARY KEY,
    TransactionId UNIQUEIDENTIFIER DEFAULT NEWID(),
    OperationType NVARCHAR(100),
    StartTime DATETIME DEFAULT GETDATE(),
    EndTime DATETIME,
    Status NVARCHAR(20), -- SUCCESS, FAILED, ROLLBACK
    ErrorMessage NVARCHAR(MAX),
    AffectedSystems NVARCHAR(200) -- MSSQL, Oracle, PostgreSQL
);

-- Procedure for logging distributed transactions
CREATE OR ALTER PROCEDURE sp_LogDistributedTransaction
    @OperationType NVARCHAR(100),
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @AffectedSystems NVARCHAR(200),
    @TransactionId UNIQUEIDENTIFIER OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @TransactionId IS NULL
        SET @TransactionId = NEWID();

    IF EXISTS (SELECT 1 FROM DistributedTransactionLog WHERE TransactionId = @TransactionId)
    BEGIN
        -- Update existing log entry
        UPDATE DistributedTransactionLog
        SET 
            EndTime = GETDATE(),
            Status = @Status,
            ErrorMessage = @ErrorMessage
        WHERE TransactionId = @TransactionId;
    END
    ELSE
    BEGIN
        -- Create new log entry
        INSERT INTO DistributedTransactionLog 
            (TransactionId, OperationType, Status, ErrorMessage, AffectedSystems)
        VALUES 
            (@TransactionId, @OperationType, @Status, @ErrorMessage, @AffectedSystems);
    END;
END;
GO

-- View to query distributed transaction logs
CREATE OR ALTER VIEW vw_DistributedTransactionHistory AS
SELECT 
    LogId,
    TransactionId,
    OperationType,
    StartTime,
    EndTime,
    DATEDIFF(SECOND, StartTime, ISNULL(EndTime, GETDATE())) as DurationSeconds,
    Status,
    ErrorMessage,
    AffectedSystems
FROM DistributedTransactionLog;
GO

-- Procedure to generate transaction report
CREATE OR ALTER PROCEDURE sp_DistributedTransactionReport
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @StartDate = ISNULL(@StartDate, DATEADD(DAY, -30, GETDATE()));
    SET @EndDate = ISNULL(@EndDate, GETDATE());

    SELECT 'Distributed Transaction Report' as ReportTitle;
    SELECT @StartDate as FromDate, @EndDate as ToDate;

    -- Summary statistics
    SELECT 
        COUNT(*) as TotalTransactions,
        SUM(CASE WHEN Status = 'SUCCESS' THEN 1 ELSE 0 END) as SuccessfulTransactions,
        SUM(CASE WHEN Status = 'FAILED' THEN 1 ELSE 0 END) as FailedTransactions,
        SUM(CASE WHEN Status = 'ROLLBACK' THEN 1 ELSE 0 END) as RolledBackTransactions,
        AVG(DATEDIFF(SECOND, StartTime, ISNULL(EndTime, GETDATE()))) as AvgDurationSeconds
    FROM DistributedTransactionLog
    WHERE StartTime BETWEEN @StartDate AND @EndDate;

    -- Detailed transaction list
    SELECT *
    FROM vw_DistributedTransactionHistory
    WHERE StartTime BETWEEN @StartDate AND @EndDate
    ORDER BY StartTime DESC;
END;
GO
