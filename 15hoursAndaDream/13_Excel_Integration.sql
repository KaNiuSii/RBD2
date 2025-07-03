
-- ==========================================
-- Excel Integration Script
-- School Management System - Excel Data Source
-- ==========================================

USE SchoolDB;
GO

-- ==========================================
-- SECTION 1: Enable Excel Data Access
-- ==========================================

-- Enable Ad Hoc Distributed Queries (if not already enabled)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- ==========================================
-- SECTION 2: Create Sample Excel Data Structure
-- ==========================================

-- Create a table to demonstrate Excel data import structure
CREATE TABLE ExcelImportLog (
    ImportId INT IDENTITY(1,1) PRIMARY KEY,
    FileName NVARCHAR(255),
    SheetName NVARCHAR(100),
    ImportDate DATETIME DEFAULT GETDATE(),
    RecordsImported INT,
    Status NVARCHAR(50),
    ErrorMessage NVARCHAR(MAX)
);

-- Create staging table for Excel imports
CREATE TABLE StudentGradesStaging (
    StudentId INT,
    StudentName NVARCHAR(100),
    Subject NVARCHAR(50),
    Grade DECIMAL(5,2),
    ExamDate DATE,
    TeacherName NVARCHAR(100),
    Comments NVARCHAR(500)
);

-- ==========================================
-- SECTION 3: Excel Reading Functions
-- ==========================================

-- Procedure to read Excel file using OPENROWSET
CREATE OR ALTER PROCEDURE sp_ReadExcelFile
    @FilePath NVARCHAR(500),
    @SheetName NVARCHAR(100) = 'Sheet1'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @Provider NVARCHAR(100);
    DECLARE @ConnectionString NVARCHAR(500);

    -- Determine provider based on file extension
    IF RIGHT(@FilePath, 4) = '.xls'
        SET @Provider = 'Microsoft.Jet.OLEDB.4.0';
    ELSE IF RIGHT(@FilePath, 5) = '.xlsx'
        SET @Provider = 'Microsoft.ACE.OLEDB.12.0';
    ELSE
    BEGIN
        PRINT 'Unsupported file format. Please use .xls or .xlsx files.';
        RETURN;
    END;

    -- Build connection string
    IF @Provider = 'Microsoft.Jet.OLEDB.4.0'
        SET @ConnectionString = 'Excel 8.0;HDR=YES;Database=' + @FilePath;
    ELSE
        SET @ConnectionString = 'Excel 12.0;HDR=YES;Database=' + @FilePath;

    -- Build dynamic SQL
    SET @SQL = 'SELECT * FROM OPENROWSET(' + CHAR(39) + @Provider + CHAR(39) + ', ' + CHAR(39) + @ConnectionString + CHAR(39) + ', ' + CHAR(39) + 'SELECT * FROM [' + @SheetName + '$]' + CHAR(39) + ')';

    BEGIN TRY
        EXEC sp_executesql @SQL;
        PRINT 'Excel file read successfully: ' + @FilePath;
    END TRY
    BEGIN CATCH
        PRINT 'Error reading Excel file: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO

-- ==========================================
-- SECTION 4: Excel Export Functions
-- ==========================================

-- Procedure to export data to Excel format (using BCP)
CREATE OR ALTER PROCEDURE sp_ExportToExcelFormat
    @QueryText NVARCHAR(MAX),
    @OutputPath NVARCHAR(500),
    @IncludeHeaders BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BCPCommand NVARCHAR(MAX);
    DECLARE @TempTable NVARCHAR(100) = 'TempExport_' + REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', '');
    DECLARE @SQL NVARCHAR(MAX);

    BEGIN TRY
        -- Create temporary table with query results
        SET @SQL = 'SELECT * INTO ' + @TempTable + ' FROM (' + @QueryText + ') AS ExportData';
        EXEC sp_executesql @SQL;

        -- Build BCP command for export
        SET @BCPCommand = 'bcp "SELECT * FROM SchoolDB.dbo.' + @TempTable + '" queryout "' + @OutputPath + '" -c -t"," -S' + @@SERVERNAME + ' -T';

        -- Execute BCP command (commented out for safety)
        -- EXEC xp_cmdshell @BCPCommand;

        -- Clean up temporary table
        SET @SQL = 'DROP TABLE ' + @TempTable;
        EXEC sp_executesql @SQL;

        PRINT 'Data export prepared successfully for: ' + @OutputPath;

    END TRY
    BEGIN CATCH
        -- Clean up on error
        IF OBJECT_ID(@TempTable) IS NOT NULL
        BEGIN
            SET @SQL = 'DROP TABLE ' + @TempTable;
            EXEC sp_executesql @SQL;
        END;

        PRINT 'Error preparing export: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO

-- ==========================================
-- SECTION 5: Excel-based Analytical Queries
-- ==========================================

-- Procedure to create analytical report that can be exported to Excel
CREATE OR ALTER PROCEDURE sp_CreateAnalyticalReport
    @ReportType NVARCHAR(50) = 'STUDENT_PERFORMANCE'
AS
BEGIN
    SET NOCOUNT ON;

    IF @ReportType = 'STUDENT_PERFORMANCE'
    BEGIN
        -- Student performance report
        SELECT 
            s.id as StudentId,
            s.firstName + ' ' + s.lastName as StudentName,
            g.value as Gender,
            y.value as SchoolYear,
            COUNT(m.id) as TotalMarks,
            AVG(CAST(m.value AS FLOAT)) as AverageGrade,
            MIN(m.value) as LowestGrade,
            MAX(m.value) as HighestGrade,
            COUNT(CASE WHEN m.value >= 90 THEN 1 END) as ExcellentGrades,
            COUNT(CASE WHEN m.value < 60 THEN 1 END) as FailingGrades
        FROM students s
            LEFT JOIN genders g ON s.genderId = g.id
            LEFT JOIN groups gr ON s.groupId = gr.id
            LEFT JOIN years y ON gr.yearId = y.id
            LEFT JOIN marks m ON s.id = m.studentId
        GROUP BY s.id, s.firstName, s.lastName, g.value, y.value
        ORDER BY AVG(CAST(m.value AS FLOAT)) DESC;
    END
    ELSE IF @ReportType = 'TEACHER_WORKLOAD'
    BEGIN
        -- Teacher workload report
        SELECT 
            t.id as TeacherId,
            t.firstName + ' ' + t.lastName as TeacherName,
            t.email,
            COUNT(DISTINCT l.id) as TotalLessons,
            COUNT(DISTINCT l.groupId) as GroupsTeaching,
            COUNT(DISTINCT l.subjectId) as SubjectsTeaching
        FROM teachers t
            LEFT JOIN lessons l ON t.id = l.teacherId
        GROUP BY t.id, t.firstName, t.lastName, t.email
        ORDER BY COUNT(DISTINCT l.id) DESC;
    END;
END;
GO

-- Test the Excel integration procedures
PRINT 'Testing Excel Integration...';

-- Test analytical reports
EXEC sp_CreateAnalyticalReport @ReportType = 'STUDENT_PERFORMANCE';

PRINT 'Excel integration setup completed successfully!';
PRINT 'Note: Ensure proper OLE DB providers are installed for Excel access.';
PRINT 'For .xlsx files, install Microsoft Access Database Engine Redistributable.';
PRINT 'Adjust file paths according to your environment.';
