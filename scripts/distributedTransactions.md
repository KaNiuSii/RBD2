# Distributed Transactions with MS DTC Script

## 1. MS DTC Configuration Check and Setup

### Step 1: Enable MSDTC Service
Run these commands in Command Prompt as Administrator:

```cmd
REM Start MSDTC service
net start msdtc

REM Configure MSDTC security settings
dcomcnfg.exe
```

### Step 2: Configure MSDTC Security (GUI Steps)
1. Open Component Services (dcomcnfg.exe)
2. Navigate to: Component Services → Computers → My Computer → Distributed Transaction Coordinator → Local DTC
3. Right-click "Local DTC" and select "Properties"
4. Go to the "Security" tab and enable:
   - Network DTC Access
   - Allow Inbound
   - Allow Outbound
   - Enable Distributed COM for this User
   - Authentication Required (recommended for production)

### Step 3: SQL Server DTC Configuration Check

```sql
-- Check if MSDTC is running and configured
USE master;
GO

-- Check DTC status
EXEC xp_cmdshell 'sc query msdtc';

-- Test DTC functionality
SELECT @@SERVERNAME AS ServerName, SERVERPROPERTY('IsClustered') AS IsClustered;

-- Check if distributed transactions are enabled
SELECT name, value, value_in_use, description
FROM sys.configurations
WHERE name LIKE '%distributed%' OR name LIKE '%remote%';
```

## 2. Basic Distributed Transaction Examples

```sql
USE SchoolManagement;
GO

-- Example 1: Simple distributed transaction across MSSQL and Oracle
CREATE PROCEDURE sp_CreateStudentContractTransaction
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Birthday DATE,
    @GenderId INT,
    @GroupId INT,
    @ParentId INT,
    @MonthlyAmount DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Start distributed transaction
    BEGIN DISTRIBUTED TRANSACTION;
    
    DECLARE @StudentId INT;
    DECLARE @ContractId INT;
    
    BEGIN TRY
        -- Insert student in local MSSQL database
        INSERT INTO students (firstName, lastName, birthday, genderId, groupId)
        VALUES (@FirstName, @LastName, @Birthday, @GenderId, @GroupId);
        
        SET @StudentId = SCOPE_IDENTITY();
        PRINT 'Student created with ID: ' + CAST(@StudentId AS VARCHAR(10));
        
        -- Insert contract in Oracle database
        EXEC ('
            DECLARE contract_id NUMBER;
            BEGIN
                SELECT contracts_seq.NEXTVAL INTO contract_id FROM DUAL;
                INSERT INTO contracts (id, studentId, parentId, startDate, endDate, monthlyAmount)
                VALUES (contract_id, ' + @StudentId + ', ' + @ParentId + ', SYSDATE, ADD_MONTHS(SYSDATE, 12), ' + @MonthlyAmount + ');
            END;
        ') AT ORACLE_LINK;
        
        PRINT 'Contract created for student ID: ' + CAST(@StudentId AS VARCHAR(10));
        
        -- Commit distributed transaction
        COMMIT TRANSACTION;
        
        PRINT 'Distributed transaction completed successfully';
        
        -- Return the new student ID
        SELECT @StudentId AS NewStudentId;
        
    END TRY
    BEGIN CATCH
        -- Rollback distributed transaction on error
        ROLLBACK TRANSACTION;
        
        PRINT 'Distributed transaction rolled back due to error: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- Test the distributed transaction
EXEC sp_CreateStudentContractTransaction
    @FirstName = 'John',
    @LastName = 'DistributedTest',
    @Birthday = '2005-01-01',
    @GenderId = 1,
    @GroupId = 1,
    @ParentId = 1,
    @MonthlyAmount = 450.00;
```

## 3. Complex Multi-System Distributed Transaction

```sql
-- Complex distributed transaction involving MSSQL, Oracle, and PostgreSQL
CREATE PROCEDURE sp_CompleteStudentEnrollmentTransaction
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Birthday DATE,
    @GenderId INT,
    @GroupId INT,
    @ParentFirstName NVARCHAR(50),
    @ParentLastName NVARCHAR(50),
    @ParentPhone NVARCHAR(20),
    @ParentEmail NVARCHAR(100),
    @MonthlyAmount DECIMAL(10,2),
    @InitialRemark NVARCHAR(500) = 'Student enrolled in the system'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Start distributed transaction
    BEGIN DISTRIBUTED TRANSACTION;
    
    DECLARE @StudentId INT;
    DECLARE @ParentId INT;
    DECLARE @ContractId INT;
    
    BEGIN TRY
        -- Step 1: Insert student in MSSQL
        INSERT INTO students (firstName, lastName, birthday, genderId, groupId)
        VALUES (@FirstName, @LastName, @Birthday, @GenderId, @GroupId);
        
        SET @StudentId = SCOPE_IDENTITY();
        PRINT 'Step 1: Student created with ID: ' + CAST(@StudentId AS VARCHAR(10));
        
        -- Step 2: Insert parent in MSSQL
        INSERT INTO parents (firstName, lastName, phoneNumber, email)
        VALUES (@ParentFirstName, @ParentLastName, @ParentPhone, @ParentEmail);
        
        SET @ParentId = SCOPE_IDENTITY();
        PRINT 'Step 2: Parent created with ID: ' + CAST(@ParentId AS VARCHAR(10));
        
        -- Step 3: Link parent to student in MSSQL
        INSERT INTO parents_students (parentId, studentId)
        VALUES (@ParentId, @StudentId);
        
        PRINT 'Step 3: Parent-student relationship created';
        
        -- Step 4: Create contract in Oracle
        EXEC ('
            DECLARE contract_id NUMBER;
            BEGIN
                SELECT contracts_seq.NEXTVAL INTO contract_id FROM DUAL;
                INSERT INTO contracts (id, studentId, parentId, startDate, endDate, monthlyAmount)
                VALUES (contract_id, ' + @StudentId + ', ' + @ParentId + ', SYSDATE, ADD_MONTHS(SYSDATE, 12), ' + @MonthlyAmount + ');
                
                -- Create initial payment records
                FOR i IN 0..2 LOOP
                    INSERT INTO payments (id, contractId, dueDate, amount, status)
                    VALUES (payments_seq.NEXTVAL, contract_id, ADD_MONTHS(SYSDATE, i), ' + @MonthlyAmount + ', ''PENDING'');
                END LOOP;
            END;
        ') AT ORACLE_LINK;
        
        PRINT 'Step 4: Contract and initial payments created in Oracle';
        
        -- Step 5: Add initial remark in PostgreSQL
        DECLARE @RemarkSQL NVARCHAR(MAX) = 
            'INSERT INTO remarks.remark (studentId, teacherId, value, severity, category) VALUES (' +
            CAST(@StudentId AS VARCHAR(10)) + ', 1, ''' + @InitialRemark + ''', ''INFO'', ''GENERAL'')';
        
        EXEC (@RemarkSQL) AT POSTGRES_LINK;
        
        PRINT 'Step 5: Initial remark added in PostgreSQL';
        
        -- Step 6: Update replica database
        INSERT INTO OPENQUERY(SQL2, 'SELECT firstName, lastName, birthday, genderId, groupId FROM SchoolManagement_Replica.dbo.students')
        VALUES (@FirstName, @LastName, @Birthday, @GenderId, @GroupId);
        
        PRINT 'Step 6: Student data replicated to SQL2';
        
        -- Commit distributed transaction
        COMMIT TRANSACTION;
        
        PRINT 'Complete enrollment transaction completed successfully';
        PRINT 'New Student ID: ' + CAST(@StudentId AS VARCHAR(10));
        PRINT 'New Parent ID: ' + CAST(@ParentId AS VARCHAR(10));
        
        -- Return the results
        SELECT 
            @StudentId AS NewStudentId,
            @ParentId AS NewParentId,
            'SUCCESS' AS TransactionStatus;
        
    END TRY
    BEGIN CATCH
        -- Rollback distributed transaction on error
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        PRINT 'Distributed transaction rolled back due to error: ' + @ErrorMsg;
        
        -- Log the error
        INSERT INTO DistributedTransactionLog (
            TransactionType,
            StartTime,
            EndTime,
            Status,
            ErrorMessage,
            UserName
        ) VALUES (
            'CompleteStudentEnrollment',
            SYSDATETIME(),
            SYSDATETIME(),
            'FAILED',
            @ErrorMsg,
            SUSER_NAME()
        );
        
        RAISERROR(@ErrorMsg, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO
```

## 4. Distributed Transaction Monitoring and Logging

```sql
-- Create a table to log distributed transactions
CREATE TABLE DistributedTransactionLog (
    LogId INT IDENTITY(1,1) PRIMARY KEY,
    TransactionType NVARCHAR(50),
    StartTime DATETIME2,
    EndTime DATETIME2,
    Duration_ms AS DATEDIFF(MILLISECOND, StartTime, EndTime),
    Status NVARCHAR(20), -- SUCCESS, FAILED, TIMEOUT
    ErrorMessage NVARCHAR(MAX),
    UserName NVARCHAR(128),
    SessionId INT,
    ServersList NVARCHAR(500),
    RecordsAffected INT
);

-- Create procedure to monitor active distributed transactions
CREATE PROCEDURE sp_MonitorDistributedTransactions
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Monitor active distributed transactions
    SELECT 
        dt.transaction_id,
        dt.transaction_begin_time,
        dt.transaction_type,
        dt.transaction_state,
        dt.transaction_status,
        s.session_id,
        s.login_name,
        s.program_name,
        s.host_name
    FROM sys.dm_tran_active_transactions dt
    LEFT JOIN sys.dm_exec_sessions s ON dt.session_id = s.session_id
    WHERE dt.transaction_type = 2; -- Distributed transaction
    
    -- Monitor DTC transactions
    SELECT 
        dtdt.transaction_id,
        dtdt.transaction_begin_time,
        dtdt.transaction_type,
        dtdt.transaction_state,
        dtdt.dtc_state
    FROM sys.dm_tran_distributed_transaction_identifier dtdt;
    
    -- Show current session transactions
    SELECT 
        st.session_id,
        st.transaction_id,
        st.is_user_transaction,
        st.is_local,
        at.transaction_begin_time,
        at.transaction_type,
        at.transaction_state
    FROM sys.dm_tran_session_transactions st
    JOIN sys.dm_tran_active_transactions at ON st.transaction_id = at.transaction_id;
END;
GO

-- Create procedure to log distributed transaction performance
CREATE PROCEDURE sp_LogDistributedTransaction
    @TransactionType NVARCHAR(50),
    @StartTime DATETIME2,
    @EndTime DATETIME2,
    @Status NVARCHAR(20),
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @ServersList NVARCHAR(500) = NULL,
    @RecordsAffected INT = NULL
AS
BEGIN
    INSERT INTO DistributedTransactionLog (
        TransactionType,
        StartTime,
        EndTime,
        Status,
        ErrorMessage,
        UserName,
        SessionId,
        ServersList,
        RecordsAffected
    ) VALUES (
        @TransactionType,
        @StartTime,
        @EndTime,
        @Status,
        @ErrorMessage,
        SUSER_NAME(),
        @@SPID,
        @ServersList,
        @RecordsAffected
    );
END;
GO
```

## 5. Error Handling and Recovery for Distributed Transactions

```sql
-- Create procedure for handling distributed transaction failures
CREATE PROCEDURE sp_HandleDistributedTransactionFailure
    @TransactionId UNIQUEIDENTIFIER = NULL,
    @ForceRollback BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorMsg NVARCHAR(MAX);
    DECLARE @TransactionCount INT;
    
    -- Check for active distributed transactions
    SELECT @TransactionCount = @@TRANCOUNT;
    
    IF @TransactionCount > 0
    BEGIN
        PRINT 'Active transaction detected. Transaction count: ' + CAST(@TransactionCount AS VARCHAR(10));
        
        IF @ForceRollback = 1
        BEGIN
            PRINT 'Force rollback requested. Rolling back all transactions...';
            
            WHILE @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END
            
            PRINT 'All transactions rolled back.';
        END
        ELSE
        BEGIN
            PRINT 'Manual intervention required. Use @ForceRollback = 1 to force rollback.';
        END
    END
    ELSE
    BEGIN
        PRINT 'No active transactions found.';
    END
    
    -- Check for orphaned distributed transactions
    IF EXISTS (SELECT 1 FROM sys.dm_tran_distributed_transaction_identifier)
    BEGIN
        PRINT 'Orphaned distributed transactions detected:';
        
        SELECT 
            dtdt.transaction_id,
            dtdt.transaction_begin_time,
            dtdt.dtc_state,
            DATEDIFF(MINUTE, dtdt.transaction_begin_time, GETDATE()) AS MinutesActive
        FROM sys.dm_tran_distributed_transaction_identifier dtdt;
        
        -- Log orphaned transactions
        INSERT INTO DistributedTransactionLog (
            TransactionType,
            StartTime,
            EndTime,
            Status,
            ErrorMessage,
            UserName
        )
        SELECT 
            'ORPHANED_TRANSACTION',
            dtdt.transaction_begin_time,
            SYSDATETIME(),
            'ORPHANED',
            'Orphaned distributed transaction detected with ID: ' + CAST(dtdt.transaction_id AS VARCHAR(50)),
            SUSER_NAME()
        FROM sys.dm_tran_distributed_transaction_identifier dtdt;
    END
END;
GO

-- Create procedure for distributed transaction health check
CREATE PROCEDURE sp_DistributedTransactionHealthCheck
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Distributed Transaction Health Check';
    PRINT '===================================';
    
    -- Check MSDTC service status
    CREATE TABLE #ServiceStatus (
        ServiceName NVARCHAR(100),
        Status NVARCHAR(50)
    );
    
    INSERT INTO #ServiceStatus 
    EXEC xp_cmdshell 'sc query msdtc | findstr STATE';
    
    IF EXISTS (SELECT 1 FROM #ServiceStatus WHERE Status LIKE '%RUNNING%')
        PRINT '✓ MSDTC Service is running';
    ELSE
        PRINT '✗ MSDTC Service is not running';
    
    DROP TABLE #ServiceStatus;
    
    -- Check DTC configuration
    SELECT 
        'DTC Configuration Check' AS CheckType,
        name,
        value,
        value_in_use
    FROM sys.configurations
    WHERE name LIKE '%distributed%';
    
    -- Check linked server connectivity for distributed transactions
    PRINT 'Testing linked server connectivity for distributed transactions...';
    
    BEGIN TRY
        -- Test Oracle
        EXEC ('SELECT 1 FROM DUAL') AT ORACLE_LINK;
        PRINT '✓ Oracle linked server connection successful';
    END TRY
    BEGIN CATCH
        PRINT '✗ Oracle linked server connection failed: ' + ERROR_MESSAGE();
    END CATCH
    
    BEGIN TRY
        -- Test PostgreSQL
        EXEC ('SELECT 1') AT POSTGRES_LINK;
        PRINT '✓ PostgreSQL linked server connection successful';
    END TRY
    BEGIN CATCH
        PRINT '✗ PostgreSQL linked server connection failed: ' + ERROR_MESSAGE();
    END CATCH
    
    BEGIN TRY
        -- Test SQL2
        EXEC ('SELECT 1') AT SQL2;
        PRINT '✓ SQL2 linked server connection successful';
    END TRY
    BEGIN CATCH
        PRINT '✗ SQL2 linked server connection failed: ' + ERROR_MESSAGE();
    END CATCH
    
    -- Show recent distributed transaction history
    SELECT TOP 10
        TransactionType,
        StartTime,
        Duration_ms,
        Status,
        UserName
    FROM DistributedTransactionLog
    ORDER BY StartTime DESC;
END;
GO
```

## 6. Distributed Transaction Cleanup and Maintenance

```sql
-- Create procedure for cleaning up completed/failed distributed transactions
CREATE PROCEDURE sp_CleanupDistributedTransactions
    @DaysToKeep INT = 30,
    @CleanupOrphanedTransactions BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DeletedRows INT;
    
    -- Clean up old log entries
    DELETE FROM DistributedTransactionLog
    WHERE StartTime < DATEADD(DAY, -@DaysToKeep, GETDATE());
    
    SET @DeletedRows = @@ROWCOUNT;
    PRINT 'Cleaned up ' + CAST(@DeletedRows AS VARCHAR(10)) + ' old log entries';
    
    -- Handle orphaned transactions if requested
    IF @CleanupOrphanedTransactions = 1
    BEGIN
        PRINT 'Checking for orphaned distributed transactions...';
        
        -- Force rollback of any active transactions older than 1 hour
        DECLARE @OldTransactions TABLE (
            transaction_id UNIQUEIDENTIFIER,
            transaction_begin_time DATETIME,
            minutes_active INT
        );
        
        INSERT INTO @OldTransactions
        SELECT 
            dtdt.transaction_id,
            dtdt.transaction_begin_time,
            DATEDIFF(MINUTE, dtdt.transaction_begin_time, GETDATE())
        FROM sys.dm_tran_distributed_transaction_identifier dtdt
        WHERE DATEDIFF(MINUTE, dtdt.transaction_begin_time, GETDATE()) > 60;
        
        IF EXISTS (SELECT 1 FROM @OldTransactions)
        BEGIN
            PRINT 'Found orphaned transactions older than 1 hour. Manual cleanup required.';
            
            SELECT 
                'ORPHANED TRANSACTIONS FOUND' AS Warning,
                transaction_id,
                transaction_begin_time,
                minutes_active
            FROM @OldTransactions;
        END
        ELSE
        BEGIN
            PRINT 'No orphaned transactions found.';
        END
    END
    
    -- Show current status
    PRINT 'Current distributed transaction status:';
    EXEC sp_MonitorDistributedTransactions;
END;
GO
```

## 7. Comprehensive Testing Script

```sql
-- Test all distributed transaction functionality
PRINT 'Testing Distributed Transaction Functionality';
PRINT '===========================================';

-- Test 1: Health check
PRINT 'Test 1: Health Check';
EXEC sp_DistributedTransactionHealthCheck;

-- Test 2: Simple distributed transaction
PRINT 'Test 2: Simple Distributed Transaction';
BEGIN TRY
    EXEC sp_CreateStudentContractTransaction
        @FirstName = 'Test',
        @LastName = 'Transaction1',
        @Birthday = '2006-01-01',
        @GenderId = 1,
        @GroupId = 1,
        @ParentId = 1,
        @MonthlyAmount = 300.00;
    
    PRINT '✓ Simple distributed transaction test passed';
END TRY
BEGIN CATCH
    PRINT '✗ Simple distributed transaction test failed: ' + ERROR_MESSAGE();
END CATCH

-- Test 3: Complex multi-system transaction
PRINT 'Test 3: Complex Multi-System Transaction';
BEGIN TRY
    EXEC sp_CompleteStudentEnrollmentTransaction
        @FirstName = 'Test',
        @LastName = 'Transaction2',
        @Birthday = '2006-02-01',
        @GenderId = 2,
        @GroupId = 2,
        @ParentFirstName = 'Parent',
        @ParentLastName = 'Test',
        @ParentPhone = '+1234567890',
        @ParentEmail = 'parent.test@email.com',
        @MonthlyAmount = 400.00,
        @InitialRemark = 'Test enrollment through distributed transaction';
    
    PRINT '✓ Complex multi-system transaction test passed';
END TRY
BEGIN CATCH
    PRINT '✗ Complex multi-system transaction test failed: ' + ERROR_MESSAGE();
END CATCH

-- Test 4: Monitor transactions
PRINT 'Test 4: Transaction Monitoring';
EXEC sp_MonitorDistributedTransactions;

-- Test 5: Show transaction logs
PRINT 'Test 5: Transaction History';
SELECT TOP 5 * FROM DistributedTransactionLog ORDER BY StartTime DESC;

PRINT 'Distributed transaction testing completed.';
```

---

**Configuration Notes:**

### Windows Firewall Settings
Add these firewall rules for MSDTC:
- Port 135 (RPC endpoint mapper)
- Dynamic RPC ports (or configure static range)

### Registry Settings (if needed)
```reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSDTC\Security]
"NetworkDtcAccess"=dword:00000001
"NetworkDtcAccessInbound"=dword:00000001
"NetworkDtcAccessOutbound"=dword:00000001
"NetworkDtcAccessTransactions"=dword:00000001
```