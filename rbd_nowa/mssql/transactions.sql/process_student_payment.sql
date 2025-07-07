CREATE OR ALTER PROCEDURE sp_ProcessStudentPayment
    @StudentId INT,
    @PaidAmount DECIMAL(10,2),
    @PaidDate DATE = NULL
AS
BEGIN
    SET XACT_ABORT ON;
    SET NOCOUNT ON;

    DECLARE @OracleResult NVARCHAR(200);
    DECLARE @ContractId INT;
    DECLARE @PaymentId INT;

    BEGIN TRY
        BEGIN TRAN;

        -- Pobierz najnowszy kontrakt dla studenta z Oracle
        SELECT TOP 1 @ContractId = c.id
        FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS c
        WHERE c.studentId = @StudentId
        ORDER BY c.id DESC;

        IF @ContractId IS NULL
            THROW 51000, 'Nie znaleziono kontraktu dla studenta w Oracle', 1;

        -- Pobierz najbliższą płatność do opłacenia
        SELECT TOP 1 @PaymentId = p.id
        FROM ORACLE_FINANCE..FINANCE_DB.PAYMENTS p
        WHERE p.contractId = @ContractId
          AND p.status = 'PENDING'
        ORDER BY p.dueDate;

        IF @PaymentId IS NULL
            THROW 51000, 'Nie znaleziono zaległej płatności dla kontraktu', 1;

        -- Wywołaj procedurę przetwarzającą płatność
        DECLARE @PLSQL NVARCHAR(MAX);
        SET @PLSQL = N'
        DECLARE v_result VARCHAR2(100);
        BEGIN
            sp_ProcessPayment(
                p_payment_id   => :paymentId,
                p_paid_amount  => :paidAmount,
                p_paid_date    => :paidDate,
                p_result       => :result
            );
        END;';

        EXEC (@PLSQL,
             @paymentId=@PaymentId,
             @paidAmount=@PaidAmount,
             @paidDate=@PaidDate,
             @result=@OracleResult OUTPUT
        ) AT ORACLE_FINANCE;

        -- Sprawdź rezultat z Oracle
       IF @OracleResult LIKE 'ERROR:%'
        BEGIN
            THROW 51000, @OracleResult, 1;
        END
        ELSE IF @OracleResult LIKE 'INFO:%'
        BEGIN
            PRINT @OracleResult;
        END

        COMMIT TRAN;
        SELECT @OracleResult AS OraclePaymentStatus, 'OK' AS Status;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Błąd płatności cross-db: %s', 16, 1, @msg);
    END CATCH
END
GO



-- 1. Znajdź pierwszą PENDING płatność i jej dane
DECLARE 
    @PaymentId INT,
    @ContractId INT,
    @FullAmount DECIMAL(10,2);

SELECT TOP 1
    @PaymentId = id,
    @ContractId = contractId,
    @FullAmount = amount
FROM ORACLE_FINANCE..FINANCE_DB.PAYMENTS
WHERE status = 'PENDING'
ORDER BY dueDate;

IF @PaymentId IS NULL
BEGIN
    PRINT 'Brak płatności PENDING do testu!';
    RETURN;
END

-- 2. Znajdź studenta z kontraktu
DECLARE @PendingStudentId INT;
SELECT @PendingStudentId = studentId
FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS
WHERE id = @ContractId;

IF @PendingStudentId IS NULL
BEGIN
    PRINT 'Brak studenta do kontraktu!';
    RETURN;
END

PRINT 'Test studentId=' + CAST(@PendingStudentId AS NVARCHAR)
    + ', contractId=' + CAST(@ContractId AS NVARCHAR)
    + ', paymentId=' + CAST(@PaymentId AS NVARCHAR);

-- 3. Wylicz kwoty wpłat
DECLARE 
    @PartialAmount DECIMAL(10,2) = ROUND(@FullAmount * 0.4, 2),
    @RemainAmount DECIMAL(10,2) = @FullAmount - ROUND(@FullAmount * 0.4, 2),
    @Today DATE;

SET @Today = CONVERT(DATE, GETDATE());

PRINT 'Częściowa wpłata: ' + CAST(@PartialAmount AS NVARCHAR);
PRINT 'Reszta do wpłaty: ' + CAST(@RemainAmount AS NVARCHAR);

-- 4. Częściowa wpłata
EXEC sp_ProcessStudentPayment
    @StudentId = @PendingStudentId,
    @PaidAmount = @PartialAmount,
    @PaidDate = @Today;

PRINT 'Po częściowej wpłacie:';
SELECT * FROM ORACLE_FINANCE..FINANCE_DB.PAYMENTS WHERE id = @PaymentId;

-- 5. Dopłata reszty
EXEC sp_ProcessStudentPayment
    @StudentId = @PendingStudentId,
    @PaidAmount = @RemainAmount,
    @PaidDate = @Today;

PRINT 'Po całkowitej wpłacie:';
SELECT * FROM ORACLE_FINANCE..FINANCE_DB.PAYMENTS WHERE id = @PaymentId;
