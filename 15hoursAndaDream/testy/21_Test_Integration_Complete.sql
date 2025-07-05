USE SchoolDB;
GO

SET XACT_ABORT ON;
-- Test 1: End-to-end student lifecycle
BEGIN TRY
    BEGIN TRANSACTION;

    -- Create new student
    INSERT INTO students (groupId, firstName, lastName, birthday, genderId)
    VALUES (1, 'Integration', 'TestStudent', '2010-01-01', 1);

    DECLARE @StudentId INT = SCOPE_IDENTITY();
    PRINT 'Created student with ID: ' + CAST(@StudentId AS VARCHAR(10));

    -- Add parent relationship
    INSERT INTO parents_students (parentId, studentId)
    VALUES (1, @StudentId);

    -- Add financial contract (Oracle)
    INSERT INTO ORACLE_FINANCE..FINANCE_DB.CONTRACTS
    (studentId, parentId, startDate, endDate, monthlyAmount)
    VALUES (@StudentId, 1, GETDATE(), DATEADD(YEAR, 1, GETDATE()), 550.00);

    -- Add grades
    INSERT INTO marks (subjectId, studentId, value, comment, weight)
    VALUES 
        (1, @StudentId, 85, 'Initial mathematics assessment', 1),
        (2, @StudentId, 90, 'Excellent English skills', 1);

    -- Add attendance
    INSERT INTO attendances (dateTimeChecked, lessonId) VALUES (GETDATE(), 1);
    DECLARE @AttendanceId INT = SCOPE_IDENTITY();

    INSERT INTO attendance_student (attendanceId, studentId, present)
    VALUES (@AttendanceId, @StudentId, 1);

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'Student lifecycle test failed: ' + ERROR_MESSAGE();
END CATCH;

-- Test 2: Multi-system data consistency
SELECT 
    'Data Consistency Check' as TestType,
    local_data.StudentCount as LocalStudents,
    oracle_data.ContractCount as OracleContracts,
    postgres_data.RemarkCount as PostgresRemarks
FROM (
    SELECT COUNT(*) as StudentCount FROM students
) local_data
CROSS JOIN (
    SELECT COUNT(*) as ContractCount FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS
) oracle_data
CROSS JOIN (
    SELECT RemarkCount FROM OPENQUERY(POSTGRES_REMARKS, 'SELECT COUNT(*) as RemarkCount FROM remarks_main.remark')
) postgres_data;


-- Test 4: Data integrity validation
CREATE OR ALTER PROCEDURE sp_ValidateDataIntegrity
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ErrorCount INT = 0;

    -- Check for orphaned records
    IF EXISTS (SELECT 1 FROM marks WHERE studentId NOT IN (SELECT id FROM students))
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        PRINT 'Error: Orphaned marks found';
    END;

    IF EXISTS (SELECT 1 FROM attendance_student WHERE studentId NOT IN (SELECT id FROM students))
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        PRINT 'Error: Orphaned attendance records found';
    END;

    -- Check for data consistency across systems
    DECLARE @LocalStudentCount INT, @OracleStudentCount INT, @PostgresStudentCount INT;

    SELECT @LocalStudentCount = COUNT(DISTINCT id) FROM students;
    SELECT @OracleStudentCount = COUNT(DISTINCT studentId) FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS;
    SELECT @PostgresStudentCount = studentCount FROM OPENQUERY(POSTGRES_REMARKS, 'SELECT COUNT(DISTINCT studentId) as studentCount FROM remarks_main.remark');

    -- Check for referential integrity
    IF EXISTS (
        SELECT 1 FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS c
        WHERE c.studentId NOT IN (SELECT id FROM students)
    )
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        PRINT 'Error: Oracle contracts reference non-existent students';
    END;

    SELECT 
        'Data Integrity Results' as TestType,
        @LocalStudentCount as LocalStudents,
        @OracleStudentCount as OracleStudents,
        @PostgresStudentCount as PostgresStudents,
        @ErrorCount as ErrorCount,
        CASE WHEN @ErrorCount = 0 THEN 'PASSED' ELSE 'FAILED' END as IntegrityStatus;
END;
GO

EXEC sp_ValidateDataIntegrity;

-- Test 5: Security and access control
SELECT 
    'Security Check' as TestType,
    l.name as LoginName,
    p.name as PrincipalName,
    p.type_desc as PrincipalType,
    dp.permission_name,
    dp.state_desc as PermissionState
FROM sys.database_permissions dp
INNER JOIN sys.database_principals p ON dp.grantee_principal_id = p.principal_id
LEFT JOIN sys.sql_logins l ON p.sid = l.sid
WHERE dp.permission_name IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
ORDER BY p.name;

-- Test 6: Backup and recovery validation
CREATE OR ALTER PROCEDURE sp_ValidateBackupRecovery
AS
BEGIN
    SET NOCOUNT ON;

    -- Check backup history
    SELECT 
        'Backup History' as TestType,
        database_name,
        backup_start_date,
        backup_finish_date,
        type,
        CASE type
            WHEN 'D' THEN 'Full'
            WHEN 'I' THEN 'Differential'
            WHEN 'L' THEN 'Log'
            ELSE 'Other'
        END as BackupType,
        backup_size / 1024 / 1024 as BackupSize_MB
    FROM msdb.dbo.backupset
    WHERE database_name = 'SchoolDB'
    ORDER BY backup_start_date DESC;

    -- Check database recovery model
    SELECT 
        'Recovery Model' as TestType,
        name as DatabaseName,
        recovery_model_desc as RecoveryModel,
        state_desc as DatabaseState
    FROM sys.databases
    WHERE name IN ('SchoolDB', 'DistributionDB');
END;
GO

EXEC sp_ValidateBackupRecovery;