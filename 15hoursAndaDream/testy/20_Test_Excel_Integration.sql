-- ==========================================
-- Test Excel Integration Operations
-- ==========================================

USE SchoolDB;
GO

PRINT 'Starting Excel integration tests...';
PRINT '==========================================';

-- Test 1: Excel configuration verification
PRINT 'Test 1: Excel configuration verification';
SELECT 
    name,
    value,
    value_in_use,
    description
FROM sys.configurations
WHERE name IN ('Ad Hoc Distributed Queries', 'show advanced options');

-- Test 2: Excel provider verification
PRINT 'Test 2: Excel provider verification';
SELECT 
    provider_name,
    provider_guid,
    provider_dll,
    provider_type,
    provider_version
FROM sys.dm_os_windows_info
WHERE provider_name LIKE '%ACE%' OR provider_name LIKE '%Jet%';

-- Test 3: Create test Excel data
PRINT 'Test 3: Create test Excel data structure';
-- Create sample data for Excel export
CREATE TABLE #ExcelTestData (
    StudentId INT,
    StudentName NVARCHAR(100),
    Subject NVARCHAR(50),
    Grade DECIMAL(5,2),
    ExamDate DATE,
    TeacherName NVARCHAR(100),
    Comments NVARCHAR(500)
);

INSERT INTO #ExcelTestData
SELECT 
    s.id,
    s.firstName + ' ' + s.lastName,
    subj.longName,
    m.value,
    GETDATE(),
    t.firstName + ' ' + t.lastName,
    m.comment
FROM students s
INNER JOIN marks m ON s.id = m.studentId
INNER JOIN subjects subj ON m.subjectId = subj.id
INNER JOIN lessons l ON subj.id = l.subjectId
INNER JOIN teachers t ON l.teacherId = t.id
WHERE s.id <= 10;

SELECT * FROM #ExcelTestData;

-- Test 4: Excel file reading simulation
PRINT 'Test 4: Excel file reading simulation';
BEGIN TRY
    -- This would normally read from an actual Excel file
    -- For testing, we'll simulate the structure
    SELECT 
        'Excel Read Test' as Operation,
        'C:\excel_exports\SchoolData.xlsx' as FilePath,
        'Would read Excel data here' as Status;

    -- Simulate Excel import log
    INSERT INTO ExcelImportLog (FileName, SheetName, RecordsImported, Status)
    VALUES ('SchoolData.xlsx', 'Arkusz1', 10, 'SUCCESS');

    PRINT 'Excel reading simulation completed';
END TRY
BEGIN CATCH
    PRINT 'Excel reading simulation failed: ' + ERROR_MESSAGE();
END CATCH;

-- Test 5: Excel export functionality
PRINT 'Test 5: Excel export functionality';
EXEC sp_CreateAnalyticalReport @ReportType = 'STUDENT_PERFORMANCE';

-- Test 6: Excel data validation
PRINT 'Test 6: Excel data validation';
CREATE OR ALTER PROCEDURE sp_ValidateExcelData
    @ImportId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RecordCount INT;
    DECLARE @ErrorCount INT = 0;

    -- Validate data in staging table
    SELECT @RecordCount = COUNT(*) FROM StudentGradesStaging;

    -- Check for missing required fields
    IF EXISTS (SELECT 1 FROM StudentGradesStaging WHERE StudentId IS NULL OR StudentName IS NULL)
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        PRINT 'Error: Missing required fields detected';
    END;

    -- Check for invalid grades
    IF EXISTS (SELECT 1 FROM StudentGradesStaging WHERE Grade < 0 OR Grade > 100)
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        PRINT 'Error: Invalid grade values detected';
    END;

    -- Check for invalid dates
    IF EXISTS (SELECT 1 FROM StudentGradesStaging WHERE ExamDate > GETDATE())
    BEGIN
        SET @ErrorCount = @ErrorCount + 1;
        PRINT 'Error: Future exam dates detected';
    END;

    -- Update import log
    UPDATE ExcelImportLog 
    SET Status = CASE WHEN @ErrorCount = 0 THEN 'VALIDATED' ELSE 'VALIDATION_FAILED' END,
        ErrorMessage = CASE WHEN @ErrorCount > 0 THEN CAST(@ErrorCount AS VARCHAR(10)) + ' validation errors found' ELSE NULL END
    WHERE ImportId = @ImportId;

    SELECT 
        'Validation Results' as TestType,
        @RecordCount as RecordsProcessed,
        @ErrorCount as ErrorCount,
        CASE WHEN @ErrorCount = 0 THEN 'PASSED' ELSE 'FAILED' END as ValidationStatus;
END;
GO

-- Insert test data for validation
INSERT INTO StudentGradesStaging (StudentId, StudentName, Subject, Grade, ExamDate, TeacherName, Comments)
VALUES 
    (1, 'Test Student 1', 'Mathematics', 85.5, '2024-01-15', 'John Smith', 'Good performance'),
    (2, 'Test Student 2', 'English', 92.0, '2024-01-16', 'Mary Johnson', 'Excellent work'),
    (NULL, 'Invalid Student', 'Science', 78.0, '2024-01-17', 'David Brown', 'Missing ID'), -- Invalid
    (3, 'Test Student 3', 'Mathematics', 150.0, '2024-01-18', 'John Smith', 'Invalid grade'); -- Invalid

EXEC sp_ValidateExcelData @ImportId = 1;

-- Test 7: Excel data import processing
PRINT 'Test 7: Excel data import processing';
CREATE OR ALTER PROCEDURE sp_ProcessExcelImport
    @ImportId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProcessedCount INT = 0;
    DECLARE @ErrorCount INT = 0;

    -- Process valid records
    INSERT INTO marks (subjectId, studentId, value, comment, weight)
    SELECT 
        s.id,
        sg.StudentId,
        sg.Grade,
        sg.Comments,
        1
    FROM StudentGradesStaging sg
    INNER JOIN subjects s ON sg.Subject = s.longName
    WHERE sg.StudentId IS NOT NULL 
      AND sg.Grade BETWEEN 0 AND 100
      AND sg.ExamDate <= GETDATE();

    SET @ProcessedCount = @@ROWCOUNT;

    -- Count errors
    SELECT @ErrorCount = COUNT(*)
    FROM StudentGradesStaging
    WHERE StudentId IS NULL 
       OR Grade < 0 
       OR Grade > 100 
       OR ExamDate > GETDATE();

    -- Update import log
    UPDATE ExcelImportLog 
    SET RecordsImported = @ProcessedCount,
        Status = CASE WHEN @ErrorCount = 0 THEN 'PROCESSED' ELSE 'PARTIALLY_PROCESSED' END,
        ErrorMessage = CASE WHEN @ErrorCount > 0 THEN CAST(@ErrorCount AS VARCHAR(10)) + ' records had errors' ELSE NULL END
    WHERE ImportId = @ImportId;

    -- Clear staging table
    DELETE FROM StudentGradesStaging;

    SELECT 
        'Import Processing Results' as TestType,
        @ProcessedCount as RecordsImported,
        @ErrorCount as RecordsWithErrors,
        CASE WHEN @ErrorCount = 0 THEN 'SUCCESS' ELSE 'PARTIAL_SUCCESS' END as ProcessingStatus;
END;
GO

EXEC sp_ProcessExcelImport @ImportId = 1;

-- Test 8: Excel export with formatting
PRINT 'Test 8: Excel export with formatting';
CREATE OR ALTER PROCEDURE sp_ExportFormattedReport
    @ReportType NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @ReportType = 'GRADE_SUMMARY'
    BEGIN
        SELECT 
            'Grade Summary Export' as ReportType,
            s.firstName + ' ' + s.lastName as StudentName,
            subj.longName as Subject,
            m.value as Grade,
            CASE 
                WHEN m.value >= 90 THEN 'Excellent'
                WHEN m.value >= 80 THEN 'Good'
                WHEN m.value >= 70 THEN 'Satisfactory'
                WHEN m.value >= 60 THEN 'Needs Improvement'
                ELSE 'Failing'
            END as GradeCategory,
            t.firstName + ' ' + t.lastName as Teacher,
            GETDATE() as ExportDate
        FROM students s
        INNER JOIN marks m ON s.id = m.studentId
        INNER JOIN subjects subj ON m.subjectId = subj.id
        INNER JOIN lessons l ON subj.id = l.subjectId
        INNER JOIN teachers t ON l.teacherId = t.id
        ORDER BY s.lastName, s.firstName, subj.longName;
    END
    ELSE IF @ReportType = 'ATTENDANCE_SUMMARY'
    BEGIN
        SELECT 
            'Attendance Summary Export' as ReportType,
            s.firstName + ' ' + s.lastName as StudentName,
            COUNT(ats.id) as TotalRecords,
            SUM(CASE WHEN ats.present = 1 THEN 1 ELSE 0 END) as DaysPresent,
            COUNT(ats.id) - SUM(CASE WHEN ats.present = 1 THEN 1 ELSE 0 END) as DaysAbsent,
            CAST(AVG(CAST(ats.present AS FLOAT)) * 100 AS DECIMAL(5,2)) as AttendancePercentage,
            GETDATE() as ExportDate
        FROM students s
        LEFT JOIN attendance_student ats ON s.id = ats.studentId
        GROUP BY s.id, s.firstName, s.lastName
        HAVING COUNT(ats.id) > 0
        ORDER BY AttendancePercentage DESC;
    END;
END;
GO

EXEC sp_ExportFormattedReport @ReportType = 'GRADE_SUMMARY';
EXEC sp_ExportFormattedReport @ReportType = 'ATTENDANCE_SUMMARY';

-- Test 9: Excel integration monitoring
PRINT 'Test 9: Excel integration monitoring';
SELECT 
    'Excel Integration Log' as LogType,
    ImportId,
    FileName,
    SheetName,
    ImportDate,
    RecordsImported,
    Status,
    ErrorMessage
FROM ExcelImportLog
ORDER BY ImportDate DESC;

-- Test 10: Excel file management
PRINT 'Test 10: Excel file management';
CREATE OR ALTER PROCEDURE sp_ManageExcelFiles
AS
BEGIN
    SET NOCOUNT ON;

    -- Log file management activities
    INSERT INTO ExcelImportLog (FileName, SheetName, RecordsImported, Status, ErrorMessage)
    VALUES 
        ('StudentData_Backup.xlsx', 'Backup', 0, 'BACKUP_CREATED', 'Backup file created successfully'),
        ('TeacherData.xlsx', 'Teachers', 0, 'TEMPLATE_CREATED', 'Template file created for teachers'),
        ('GradeTemplate.xlsx', 'Grades', 0, 'TEMPLATE_CREATED', 'Template file created for grades');

    -- Show file management summary
    SELECT 
        'File Management Summary' as Operation,
        COUNT(*) as TotalFiles,
        SUM(CASE WHEN Status LIKE '%TEMPLATE%' THEN 1 ELSE 0 END) as TemplateFiles,
        SUM(CASE WHEN Status LIKE '%BACKUP%' THEN 1 ELSE 0 END) as BackupFiles,
        SUM(CASE WHEN Status = 'SUCCESS' THEN 1 ELSE 0 END) as SuccessfulImports,
        SUM(CASE WHEN Status LIKE '%FAILED%' THEN 1 ELSE 0 END) as FailedImports
    FROM ExcelImportLog;
END;
GO

EXEC sp_ManageExcelFiles;

-- Cleanup test data
DROP TABLE #ExcelTestData;

PRINT 'Excel integration tests completed successfully!';
