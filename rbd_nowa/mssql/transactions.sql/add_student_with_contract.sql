CREATE OR ALTER PROCEDURE sp_AddStudentWithFinanceContract
    @GroupId INT,
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Birthday DATE = NULL,
    @GenderId INT = NULL,
    @ParentId INT,
    @ContractStart DATE,
    @ContractEnd DATE,
    @MonthlyAmount DECIMAL(10,2),
    @StudentId INT OUTPUT,
    @OracleContractId INT OUTPUT
AS
BEGIN
    SET XACT_ABORT ON;  -- rollback automatyczny przy errorach
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        -- 1. Dodanie ucznia w MSSQL
        EXEC sp_CreateStudent 
            @GroupId=@GroupId, 
            @FirstName=@FirstName, 
            @LastName=@LastName, 
            @Birthday=@Birthday, 
            @GenderId=@GenderId, 
            @StudentId=@StudentId OUTPUT;

        -- 2. Powiązanie z rodzicem 
        INSERT INTO parents_students (parentId, studentId)
        VALUES (@ParentId, @StudentId);

        -- 3. Wywołanie procedury PL/SQL w Oracle przez linked server
        DECLARE @PLSQL NVARCHAR(MAX), @ParamDef NVARCHAR(500);
        SET @PLSQL = N'
        DECLARE
            v_contract_id NUMBER;
        BEGIN
            sp_CreateContractWithPayments(
                p_student_id     => :studentId,
                p_parent_id      => :parentId,
                p_start_date     => :startDate,
                p_end_date       => :endDate,
                p_monthly_amount => :monthlyAmount,
                p_contract_id    => :contractId
            );
        END;';
        SET @ParamDef = N'@studentId INT, @parentId INT, @startDate DATE, @endDate DATE, @monthlyAmount DECIMAL(10,2), @contractId INT OUTPUT';

        EXEC (@PLSQL, 
              @studentId=@StudentId, 
              @parentId=@ParentId, 
              @startDate=@ContractStart, 
              @endDate=@ContractEnd, 
              @monthlyAmount=@MonthlyAmount, 
              @contractId=@OracleContractId OUTPUT
        ) AT ORACLE_FINANCE;

        --SELECT * FROM OPENQUERY(ORACLE_LINK, 'SELECT id FROM contracts WHERE studentId = ' + CAST(@StudentId AS VARCHAR(10)))
		SELECT * FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS c WHERE c.studentId = @StudentId

        COMMIT TRAN;

        SELECT @StudentId AS StudentId, @OracleContractId AS OracleContractId, 'OK' AS Status;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Błąd w trakcie transakcji: %s', 16, 1, @msg);
    END CATCH
END
GO

DECLARE 
    @StudentId INT = NULL, 
    @OracleContractId INT = NULL;

BEGIN TRY
    EXEC sp_AddStudentWithFinanceContract
        @GroupId = 1,
        @FirstName = N'AnnaTest',
        @LastName = N'Testowa',
        @Birthday = '2012-05-20',
        @GenderId = 2,
        @ParentId = 3,
        @ContractStart = '2025-09-01',
        @ContractEnd = '2026-06-30',
        @MonthlyAmount = 1111.50,
        @StudentId = @StudentId OUTPUT,
        @OracleContractId = @OracleContractId OUTPUT;

    SELECT 'Student w MSSQL' AS Info, * FROM students WHERE id = @StudentId;
    SELECT 'Rodzic-Student' AS Info, * FROM parents_students WHERE studentId = @StudentId;
    SELECT 'Kontrakt Oracle' AS Info, * FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS WHERE id = @OracleContractId;
    SELECT 'Payments Oracle' AS Info, * FROM ORACLE_FINANCE..FINANCE_DB.PAYMENTS WHERE contractId = @OracleContractId;
END TRY
BEGIN CATCH
    THROW;
END CATCH

EXEC sp_serveroption 
    @server = 'ORACLE_FINANCE', 
    @optname = 'rpc', 
    @optvalue = 'true';

EXEC sp_serveroption 
    @server = 'ORACLE_FINANCE', 
    @optname = 'rpc out', 
    @optvalue = 'true';