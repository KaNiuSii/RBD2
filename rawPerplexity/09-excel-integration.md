# Excel Integration with SQL Server

## 1. Prepare an Excel File for Analytics

### Step 1: Create the Excel Workbook
1. Open Microsoft Excel
2. Create a new workbook with the following sheets:

#### Sheet1: StudentAnalytics
Create a sheet with these columns:
```
StudentID | AnalysisDate | AcademicScore | BehavioralScore | AttendanceScore | OverallScore | Comments
```

#### Sheet2: GradeDistribution
Create a sheet with these columns:
```
SubjectID | SubjectName | Grade1 | Grade2 | Grade3 | Grade4 | Grade5 | Grade6 | AverageGrade
```

#### Sheet3: TeacherPerformance
Create a sheet with these columns:
```
TeacherID | TeacherName | StudentSatisfaction | ParentSatisfaction | AdministrationSatisfaction | OverallRating | Comments
```

### Step 2: Save the Excel File
Save the workbook as `SchoolAnalytics.xlsx` in a location accessible to your SQL Server (e.g., `C:\Data\SchoolAnalytics.xlsx`).

## 2. Generate Sample Data for the Excel File

```sql
-- Create a temporary table to hold student data
USE SchoolManagement;
GO

CREATE TABLE #TempStudentAnalytics (
    StudentID INT,
    StudentName NVARCHAR(100),
    GroupID INT,
    AcademicScore DECIMAL(4,2),
    BehavioralScore DECIMAL(4,2),
    AttendanceScore DECIMAL(4,2),
    OverallScore DECIMAL(4,2),
    Comments NVARCHAR(255)
);

-- Insert data for the first 50 students
INSERT INTO #TempStudentAnalytics (StudentID, StudentName, GroupID, AcademicScore, BehavioralScore, AttendanceScore, OverallScore, Comments)
SELECT TOP 50
    s.id,
    s.firstName + ' ' + s.lastName,
    s.groupId,
    -- Generate academic score based on average of marks
    ROUND(COALESCE((SELECT AVG(CAST(value AS DECIMAL(4,2))) FROM marks WHERE studentId = s.id), 3.5), 2) AS AcademicScore,
    -- Generate random behavioral score
    ROUND(2 + (RAND(CHECKSUM(NEWID())) * 4), 2) AS BehavioralScore,
    -- Generate random attendance score
    ROUND(2 + (RAND(CHECKSUM(NEWID())) * 4), 2) AS AttendanceScore,
    -- Calculate overall score
    0.0, -- Will be updated
    CASE 
        WHEN COALESCE((SELECT AVG(CAST(value AS DECIMAL(4,2))) FROM marks WHERE studentId = s.id), 3.5) > 5.0 THEN 'Excellent academic performance'
        WHEN COALESCE((SELECT AVG(CAST(value AS DECIMAL(4,2))) FROM marks WHERE studentId = s.id), 3.5) > 4.0 THEN 'Good academic performance'
        WHEN COALESCE((SELECT AVG(CAST(value AS DECIMAL(4,2))) FROM marks WHERE studentId = s.id), 3.5) > 3.0 THEN 'Average academic performance'
        ELSE 'Needs academic improvement'
    END
FROM students s
ORDER BY NEWID();

-- Update overall score
UPDATE #TempStudentAnalytics
SET OverallScore = ROUND((AcademicScore * 0.5) + (BehavioralScore * 0.3) + (AttendanceScore * 0.2), 2);

-- Create a temporary table to hold grade distribution data
CREATE TABLE #TempGradeDistribution (
    SubjectID INT,
    SubjectName NVARCHAR(100),
    Grade1 INT,
    Grade2 INT,
    Grade3 INT,
    Grade4 INT,
    Grade5 INT,
    Grade6 INT,
    AverageGrade DECIMAL(4,2)
);

-- Insert data for all subjects
INSERT INTO #TempGradeDistribution (SubjectID, SubjectName)
SELECT id, longName
FROM subjects;

-- Update with grade distribution
UPDATE #TempGradeDistribution
SET 
    Grade1 = ABS(CHECKSUM(NEWID())) % 10,
    Grade2 = ABS(CHECKSUM(NEWID())) % 15,
    Grade3 = ABS(CHECKSUM(NEWID())) % 25,
    Grade4 = ABS(CHECKSUM(NEWID())) % 30,
    Grade5 = ABS(CHECKSUM(NEWID())) % 25,
    Grade6 = ABS(CHECKSUM(NEWID())) % 15;

-- Update average grade
UPDATE #TempGradeDistribution
SET AverageGrade = ROUND(
    CAST((Grade1*1 + Grade2*2 + Grade3*3 + Grade4*4 + Grade5*5 + Grade6*6) AS DECIMAL(10,2)) / 
    CAST((Grade1 + Grade2 + Grade3 + Grade4 + Grade5 + Grade6) AS DECIMAL(10,2)), 
    2);

-- Create a temporary table to hold teacher performance data
CREATE TABLE #TempTeacherPerformance (
    TeacherID INT,
    TeacherName NVARCHAR(100),
    StudentSatisfaction DECIMAL(4,2),
    ParentSatisfaction DECIMAL(4,2),
    AdministrationSatisfaction DECIMAL(4,2),
    OverallRating DECIMAL(4,2),
    Comments NVARCHAR(255)
);

-- Insert data for all teachers
INSERT INTO #TempTeacherPerformance (TeacherID, TeacherName)
SELECT id, firstName + ' ' + lastName
FROM teachers;

-- Update with random satisfaction scores
UPDATE #TempTeacherPerformance
SET 
    StudentSatisfaction = ROUND(2 + (RAND(CHECKSUM(NEWID())) * 4), 2),
    ParentSatisfaction = ROUND(2 + (RAND(CHECKSUM(NEWID())) * 4), 2),
    AdministrationSatisfaction = ROUND(2 + (RAND(CHECKSUM(NEWID())) * 4), 2);

-- Update overall rating
UPDATE #TempTeacherPerformance
SET 
    OverallRating = ROUND((StudentSatisfaction + ParentSatisfaction + AdministrationSatisfaction) / 3, 2),
    Comments = CASE 
        WHEN (StudentSatisfaction + ParentSatisfaction + AdministrationSatisfaction) / 3 > 5.0 THEN 'Outstanding performance'
        WHEN (StudentSatisfaction + ParentSatisfaction + AdministrationSatisfaction) / 3 > 4.0 THEN 'Excellent performance'
        WHEN (StudentSatisfaction + ParentSatisfaction + AdministrationSatisfaction) / 3 > 3.0 THEN 'Good performance'
        ELSE 'Satisfactory performance'
    END;

-- Display data for export to Excel
SELECT * FROM #TempStudentAnalytics;
SELECT * FROM #TempGradeDistribution;
SELECT * FROM #TempTeacherPerformance;

-- Clean up temporary tables
DROP TABLE #TempStudentAnalytics;
DROP TABLE #TempGradeDistribution;
DROP TABLE #TempTeacherPerformance;
```

### Step 3: Export SQL Server Data to Excel
1. Run the SQL script above
2. Copy the results from each query to the appropriate Excel sheet
3. Format the data in Excel as needed
4. Save the Excel file

## 3. Configure Excel as a Linked Server

```sql
-- Enable Ad Hoc Distributed Queries (if not already enabled)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- Create Excel linked server
EXEC sp_addlinkedserver 
    @server = 'EXCEL_ANALYTICS',
    @srvproduct = 'Excel',
    @provider = 'Microsoft.ACE.OLEDB.12.0',
    @datasrc = 'C:\Data\SchoolAnalytics.xlsx',  -- Replace with your actual file path
    @provstr = 'Excel 12.0;HDR=YES;IMEX=1;';
GO

-- Configure server options for Excel
EXEC sp_serveroption 'EXCEL_ANALYTICS', 'collation compatible', 'false';
EXEC sp_serveroption 'EXCEL_ANALYTICS', 'data access', 'true';
EXEC sp_serveroption 'EXCEL_ANALYTICS', 'dist', 'false';
EXEC sp_serveroption 'EXCEL_ANALYTICS', 'pub', 'false';
EXEC sp_serveroption 'EXCEL_ANALYTICS', 'rpc', 'false';
EXEC sp_serveroption 'EXCEL_ANALYTICS', 'rpc out', 'false';
EXEC sp_serveroption 'EXCEL_ANALYTICS', 'sub', 'false';
EXEC sp_serveroption 'EXCEL_ANALYTICS', 'connect timeout', '0';
GO

-- Test the linked server connection
SELECT * FROM EXCEL_ANALYTICS...[StudentAnalytics$];
GO
```

## 4. Query Excel Data Using OPENROWSET

```sql
-- Query Excel data without creating a linked server
SELECT * FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
    'SELECT * FROM [StudentAnalytics$]'
);

-- Query specific sheet with filter
SELECT 
    StudentID, 
    AcademicScore, 
    BehavioralScore, 
    AttendanceScore, 
    OverallScore
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
    'SELECT StudentID, AcademicScore, BehavioralScore, AttendanceScore, OverallScore FROM [StudentAnalytics$] WHERE OverallScore > 4.0'
);

-- Query another sheet
SELECT * FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
    'SELECT * FROM [GradeDistribution$]'
);
```

## 5. Create Views for Excel Data

```sql
-- Create a view for student analytics data
CREATE VIEW vw_ExcelStudentAnalytics AS
SELECT 
    e.StudentID,
    s.firstName + ' ' + s.lastName AS StudentName,
    s.groupId,
    g.value AS AcademicYear,
    e.AcademicScore,
    e.BehavioralScore,
    e.AttendanceScore,
    e.OverallScore,
    e.Comments
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
    'SELECT * FROM [StudentAnalytics$]'
) e
JOIN students s ON e.StudentID = s.id
JOIN groups gr ON s.groupId = gr.id
JOIN years g ON gr.yearId = g.id;
GO

-- Create a view for grade distribution
CREATE VIEW vw_ExcelGradeDistribution AS
SELECT 
    e.SubjectID,
    s.longName AS SubjectName,
    e.Grade1,
    e.Grade2,
    e.Grade3,
    e.Grade4,
    e.Grade5,
    e.Grade6,
    e.AverageGrade
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
    'SELECT * FROM [GradeDistribution$]'
) e
JOIN subjects s ON e.SubjectID = s.id;
GO

-- Create a view for teacher performance
CREATE VIEW vw_ExcelTeacherPerformance AS
SELECT 
    e.TeacherID,
    t.firstName + ' ' + t.lastName AS TeacherName,
    e.StudentSatisfaction,
    e.ParentSatisfaction,
    e.AdministrationSatisfaction,
    e.OverallRating,
    e.Comments
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
    'SELECT * FROM [TeacherPerformance$]'
) e
JOIN teachers t ON e.TeacherID = t.id;
GO
```

## 6. Combine Excel Data with Database Data

```sql
-- Create a comprehensive view combining Excel analytics with database data
CREATE VIEW vw_StudentPerformanceAnalysis AS
SELECT 
    s.id AS StudentID,
    s.firstName + ' ' + s.lastName AS StudentName,
    g.value AS AcademicYear,
    gr.id AS GroupID,
    t.firstName + ' ' + t.lastName AS HomeTeacher,
    
    -- Academic data from database
    CAST(AVG(CAST(m.value AS DECIMAL(4,2))) AS DECIMAL(4,2)) AS DatabaseAverageGrade,
    COUNT(m.id) AS NumberOfGrades,
    
    -- Analytics data from Excel
    e.AcademicScore AS ExcelAcademicScore,
    e.BehavioralScore AS ExcelBehavioralScore,
    e.AttendanceScore AS ExcelAttendanceScore,
    e.OverallScore AS ExcelOverallScore,
    e.Comments AS AnalyticsComments,
    
    -- Attendance data from database
    CAST(
        (SELECT COUNT(*) FROM attendance_student ast
         JOIN attendances a ON ast.attendanceId = a.id
         JOIN lessons l ON a.lessonId = l.id
         WHERE ast.studentId = s.id AND ast.present = 1) AS DECIMAL(10,2)
    ) /
    CASE 
        WHEN (SELECT COUNT(*) FROM attendance_student ast
              JOIN attendances a ON ast.attendanceId = a.id
              JOIN lessons l ON a.lessonId = l.id
              WHERE ast.studentId = s.id) = 0 THEN 1
        ELSE (SELECT COUNT(*) FROM attendance_student ast
              JOIN attendances a ON ast.attendanceId = a.id
              JOIN lessons l ON a.lessonId = l.id
              WHERE ast.studentId = s.id)
    END * 100 AS AttendancePercentage,
    
    -- Contract data from Oracle (if linked server configured)
    o.ContractStatus,
    o.MonthlyFee,
    o.PaymentStatus,
    
    -- Remarks data from PostgreSQL (if linked server configured)
    r.RemarkCount,
    r.LastRemarkDate,
    r.RemarkSeverity
FROM students s
JOIN groups gr ON s.groupId = gr.id
JOIN years g ON gr.yearId = g.id
JOIN teachers t ON gr.home_teacher_id = t.id
LEFT JOIN marks m ON s.id = m.studentId

-- Join with Excel data
LEFT JOIN OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
    'SELECT * FROM [StudentAnalytics$]'
) e ON s.id = e.StudentID

-- Join with Oracle data (if available)
LEFT JOIN (
    SELECT 
        studentId,
        CASE 
            WHEN endDate < GETDATE() THEN 'EXPIRED'
            ELSE 'ACTIVE'
        END AS ContractStatus,
        monthlyAmount AS MonthlyFee,
        CASE 
            WHEN EXISTS (SELECT 1 FROM ORACLE_LINK..payments p 
                        WHERE p.contractId = c.id AND p.status = 'OVERDUE') THEN 'OVERDUE'
            WHEN EXISTS (SELECT 1 FROM ORACLE_LINK..payments p 
                        WHERE p.contractId = c.id AND p.status = 'PENDING') THEN 'PENDING'
            ELSE 'PAID'
        END AS PaymentStatus
    FROM ORACLE_LINK..contracts c
) o ON s.id = o.studentId

-- Join with PostgreSQL data (if available)
LEFT JOIN (
    SELECT 
        studentId,
        COUNT(*) AS RemarkCount,
        MAX(created_date) AS LastRemarkDate,
        MAX(severity) AS RemarkSeverity
    FROM OPENQUERY(POSTGRES_LINK, '
        SELECT studentId, created_date, severity
        FROM remarks.remark
    ')
    GROUP BY studentId
) r ON s.id = r.studentId

GROUP BY 
    s.id, s.firstName, s.lastName, g.value, gr.id, t.firstName, t.lastName,
    e.AcademicScore, e.BehavioralScore, e.AttendanceScore, e.OverallScore, e.Comments,
    o.ContractStatus, o.MonthlyFee, o.PaymentStatus,
    r.RemarkCount, r.LastRemarkDate, r.RemarkSeverity;
GO
```

## 7. Create Analytical Stored Procedures Using Excel Data

```sql
-- Create a procedure to generate student performance report
CREATE PROCEDURE sp_StudentPerformanceReport
    @AcademicYear INT = NULL,
    @GroupID INT = NULL,
    @MinOverallScore DECIMAL(4,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.StudentID,
        s.StudentName,
        s.AcademicYear,
        s.GroupID,
        s.HomeTeacher,
        s.DatabaseAverageGrade,
        s.ExcelAcademicScore,
        s.ExcelBehavioralScore,
        s.ExcelAttendanceScore,
        s.ExcelOverallScore,
        s.AttendancePercentage,
        s.PaymentStatus,
        s.RemarkCount
    FROM vw_StudentPerformanceAnalysis s
    WHERE 
        (@AcademicYear IS NULL OR s.AcademicYear = @AcademicYear)
        AND (@GroupID IS NULL OR s.GroupID = @GroupID)
        AND (@MinOverallScore IS NULL OR s.ExcelOverallScore >= @MinOverallScore)
    ORDER BY s.ExcelOverallScore DESC;
END;
GO

-- Create a procedure to generate subject performance report
CREATE PROCEDURE sp_SubjectPerformanceReport
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get grade distribution from Excel
    SELECT 
        e.SubjectID,
        s.longName AS SubjectName,
        e.Grade1,
        e.Grade2,
        e.Grade3,
        e.Grade4,
        e.Grade5,
        e.Grade6,
        e.AverageGrade AS ExcelAverageGrade,
        
        -- Compare with actual database grades
        CAST(AVG(CAST(m.value AS DECIMAL(4,2))) AS DECIMAL(4,2)) AS DatabaseAverageGrade,
        COUNT(m.id) AS TotalGradesInDatabase,
        
        -- Variation
        ABS(e.AverageGrade - AVG(CAST(m.value AS DECIMAL(4,2)))) AS AverageVariation
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
        'SELECT * FROM [GradeDistribution$]'
    ) e
    JOIN subjects s ON e.SubjectID = s.id
    LEFT JOIN marks m ON s.id = m.subjectId
    GROUP BY 
        e.SubjectID, s.longName, e.Grade1, e.Grade2, e.Grade3, 
        e.Grade4, e.Grade5, e.Grade6, e.AverageGrade
    ORDER BY ABS(e.AverageGrade - AVG(CAST(m.value AS DECIMAL(4,2)))) DESC;
END;
GO

-- Create a procedure to generate teacher performance report
CREATE PROCEDURE sp_TeacherPerformanceReport
    @MinOverallRating DECIMAL(4,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get teacher performance from Excel
    SELECT 
        e.TeacherID,
        t.firstName + ' ' + t.lastName AS TeacherName,
        e.StudentSatisfaction,
        e.ParentSatisfaction,
        e.AdministrationSatisfaction,
        e.OverallRating,
        e.Comments,
        
        -- Get actual teaching stats
        (SELECT COUNT(DISTINCT groupId) FROM lessons WHERE teacherId = t.id) AS GroupsCount,
        (SELECT COUNT(DISTINCT subjectId) FROM lessons WHERE teacherId = t.id) AS SubjectsCount,
        
        -- Get average marks
        CAST(
            (SELECT AVG(CAST(m.value AS DECIMAL(4,2)))
             FROM marks m
             JOIN lessons l ON m.subjectId = l.subjectId
             WHERE l.teacherId = t.id) AS DECIMAL(4,2)
        ) AS AverageStudentGrade
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;Database=C:\Data\SchoolAnalytics.xlsx;HDR=YES;IMEX=1',
        'SELECT * FROM [TeacherPerformance$]'
    ) e
    JOIN teachers t ON e.TeacherID = t.id
    WHERE (@MinOverallRating IS NULL OR e.OverallRating >= @MinOverallRating)
    ORDER BY e.OverallRating DESC;
END;
GO
```

## 8. Create an Excel Analytical Database

```sql
-- Create a dedicated database for analytics
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SchoolAnalytics')
BEGIN
    ALTER DATABASE SchoolAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SchoolAnalytics;
END
GO

CREATE DATABASE SchoolAnalytics;
GO

USE SchoolAnalytics;
GO

-- Create analytics tables to store Excel data
CREATE TABLE StudentAnalytics (
    AnalyticsID INT IDENTITY(1,1) PRIMARY KEY,
    StudentID INT NOT NULL,
    AnalysisDate DATE DEFAULT GETDATE(),
    AcademicScore DECIMAL(4,2),
    BehavioralScore DECIMAL(4,2),
    AttendanceScore DECIMAL(4,2),
    OverallScore DECIMAL(4,2),
    Comments NVARCHAR(255)
);

CREATE TABLE GradeDistribution (
    DistributionID INT IDENTITY(1,1) PRIMARY KEY,
    SubjectID INT NOT NULL,
    AnalysisDate DATE DEFAULT GETDATE(),
    Grade1 INT,
    Grade2 INT,
    Grade3 INT,
    Grade4 INT,
    Grade5 INT,
    Grade6 INT,
    AverageGrade DECIMAL(4,2)
);

CREATE TABLE TeacherPerformance (
    PerformanceID INT IDENTITY(1,1) PRIMARY KEY,
    TeacherID INT NOT NULL,
    AnalysisDate DATE DEFAULT GETDATE(),
    StudentSatisfaction DECIMAL(4,2),
    ParentSatisfaction DECIMAL(4,2),
    AdministrationSatisfaction DECIMAL(4,2),
    OverallRating DECIMAL(4,2),
    Comments NVARCHAR(255)
);

-- Create a stored procedure to import Excel data
CREATE PROCEDURE sp_ImportExcelData
    @ExcelFilePath NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Delete existing data
    TRUNCATE TABLE StudentAnalytics;
    TRUNCATE TABLE GradeDistribution;
    TRUNCATE TABLE TeacherPerformance;
    
    -- Import student analytics
    INSERT INTO StudentAnalytics (
        StudentID, 
        AcademicScore, 
        BehavioralScore, 
        AttendanceScore, 
        OverallScore, 
        Comments
    )
    SELECT 
        StudentID, 
        AcademicScore, 
        BehavioralScore, 
        AttendanceScore, 
        OverallScore, 
        Comments
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;Database=' + @ExcelFilePath + ';HDR=YES;IMEX=1',
        'SELECT * FROM [StudentAnalytics$]'
    );
    
    -- Import grade distribution
    INSERT INTO GradeDistribution (
        SubjectID, 
        Grade1, 
        Grade2, 
        Grade3, 
        Grade4, 
        Grade5, 
        Grade6, 
        AverageGrade
    )
    SELECT 
        SubjectID, 
        Grade1, 
        Grade2, 
        Grade3, 
        Grade4, 
        Grade5, 
        Grade6, 
        AverageGrade
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;Database=' + @ExcelFilePath + ';HDR=YES;IMEX=1',
        'SELECT * FROM [GradeDistribution$]'
    );
    
    -- Import teacher performance
    INSERT INTO TeacherPerformance (
        TeacherID, 
        StudentSatisfaction, 
        ParentSatisfaction, 
        AdministrationSatisfaction, 
        OverallRating, 
        Comments
    )
    SELECT 
        TeacherID, 
        StudentSatisfaction, 
        ParentSatisfaction, 
        AdministrationSatisfaction, 
        OverallRating, 
        Comments
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;Database=' + @ExcelFilePath + ';HDR=YES;IMEX=1',
        'SELECT * FROM [TeacherPerformance$]'
    );
    
    -- Return summary
    SELECT 'StudentAnalytics' AS TableName, COUNT(*) AS RecordsImported FROM StudentAnalytics
    UNION ALL
    SELECT 'GradeDistribution' AS TableName, COUNT(*) AS RecordsImported FROM GradeDistribution
    UNION ALL
    SELECT 'TeacherPerformance' AS TableName, COUNT(*) AS RecordsImported FROM TeacherPerformance;
END;
GO

-- Create a linked server to the main database
EXEC sp_addlinkedserver 
    @server = 'SCHOOL_MAIN',
    @srvproduct = 'SQL Server';
GO

-- Configure server options
EXEC sp_serveroption 'SCHOOL_MAIN', 'collation compatible', 'true';
EXEC sp_serveroption 'SCHOOL_MAIN', 'data access', 'true';
EXEC sp_serveroption 'SCHOOL_MAIN', 'rpc', 'true';
EXEC sp_serveroption 'SCHOOL_MAIN', 'rpc out', 'true';
GO

-- Test import procedure
EXEC sp_ImportExcelData 'C:\Data\SchoolAnalytics.xlsx';
GO

-- Create integrated views
CREATE VIEW vw_StudentAnalyticsIntegrated AS
SELECT 
    sa.StudentID,
    s.firstName + ' ' + s.lastName AS StudentName,
    s.groupId AS GroupID,
    g.value AS AcademicYear,
    t.firstName + ' ' + t.lastName AS HomeTeacher,
    sa.AcademicScore,
    sa.BehavioralScore,
    sa.AttendanceScore,
    sa.OverallScore,
    sa.Comments,
    sa.AnalysisDate
FROM StudentAnalytics sa
JOIN SCHOOL_MAIN.SchoolManagement.dbo.students s ON sa.StudentID = s.id
JOIN SCHOOL_MAIN.SchoolManagement.dbo.groups gr ON s.groupId = gr.id
JOIN SCHOOL_MAIN.SchoolManagement.dbo.years g ON gr.yearId = g.id
JOIN SCHOOL_MAIN.SchoolManagement.dbo.teachers t ON gr.home_teacher_id = t.id;
GO

-- Create a comprehensive analytics view
CREATE VIEW vw_ComprehensiveAnalytics AS
SELECT 
    s.StudentID,
    s.StudentName,
    s.GroupID,
    s.AcademicYear,
    s.HomeTeacher,
    s.AcademicScore,
    s.BehavioralScore,
    s.AttendanceScore,
    s.OverallScore,
    
    -- Get subject grade distribution
    (SELECT AVG(AverageGrade) FROM GradeDistribution) AS SchoolAverageGrade,
    
    -- Get teacher performance
    tp.OverallRating AS TeacherRating,
    
    -- Calculate performance percentile
    CAST(
        (SELECT COUNT(*) FROM vw_StudentAnalyticsIntegrated 
         WHERE OverallScore <= s.OverallScore) AS FLOAT
    ) / 
    (SELECT COUNT(*) FROM vw_StudentAnalyticsIntegrated) * 100 AS PerformancePercentile
FROM vw_StudentAnalyticsIntegrated s
JOIN SCHOOL_MAIN.SchoolManagement.dbo.teachers t ON s.HomeTeacher = t.firstName + ' ' + t.lastName
LEFT JOIN TeacherPerformance tp ON t.id = tp.TeacherID;
GO
```

## 9. Generate Analytics Report for Export

```sql
-- Create a stored procedure to generate a complete analytics report
CREATE PROCEDURE sp_GenerateAnalyticsReport
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Overall School Performance
    SELECT 
        'Overall School Performance' AS ReportSection,
        AVG(AcademicScore) AS AvgAcademicScore,
        AVG(BehavioralScore) AS AvgBehavioralScore,
        AVG(AttendanceScore) AS AvgAttendanceScore,
        AVG(OverallScore) AS AvgOverallScore,
        MIN(OverallScore) AS MinOverallScore,
        MAX(OverallScore) AS MaxOverallScore,
        STDEV(OverallScore) AS StdDevOverallScore
    FROM StudentAnalytics;
    
    -- 2. Performance by Group
    SELECT 
        'Performance by Group' AS ReportSection,
        gr.id AS GroupID,
        y.value AS AcademicYear,
        t.firstName + ' ' + t.lastName AS HomeTeacher,
        AVG(sa.AcademicScore) AS AvgAcademicScore,
        AVG(sa.BehavioralScore) AS AvgBehavioralScore,
        AVG(sa.AttendanceScore) AS AvgAttendanceScore,
        AVG(sa.OverallScore) AS AvgOverallScore,
        COUNT(sa.StudentID) AS StudentCount
    FROM StudentAnalytics sa
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.students s ON sa.StudentID = s.id
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.groups gr ON s.groupId = gr.id
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.years y ON gr.yearId = y.id
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.teachers t ON gr.home_teacher_id = t.id
    GROUP BY gr.id, y.value, t.firstName, t.lastName
    ORDER BY AVG(sa.OverallScore) DESC;
    
    -- 3. Subject Performance
    SELECT 
        'Subject Performance' AS ReportSection,
        s.id AS SubjectID,
        s.longName AS SubjectName,
        gd.Grade1,
        gd.Grade2,
        gd.Grade3,
        gd.Grade4,
        gd.Grade5,
        gd.Grade6,
        gd.AverageGrade,
        
        -- Actual grades from database
        AVG(CAST(m.value AS DECIMAL(4,2))) AS ActualAverageGrade,
        COUNT(m.id) AS GradeCount
    FROM GradeDistribution gd
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.subjects s ON gd.SubjectID = s.id
    LEFT JOIN SCHOOL_MAIN.SchoolManagement.dbo.marks m ON s.id = m.subjectId
    GROUP BY 
        s.id, s.longName, gd.Grade1, gd.Grade2, gd.Grade3, 
        gd.Grade4, gd.Grade5, gd.Grade6, gd.AverageGrade
    ORDER BY gd.AverageGrade DESC;
    
    -- 4. Teacher Performance
    SELECT 
        'Teacher Performance' AS ReportSection,
        t.id AS TeacherID,
        t.firstName + ' ' + t.lastName AS TeacherName,
        tp.StudentSatisfaction,
        tp.ParentSatisfaction,
        tp.AdministrationSatisfaction,
        tp.OverallRating,
        
        -- Teaching load
        (SELECT COUNT(DISTINCT l.groupId) FROM SCHOOL_MAIN.SchoolManagement.dbo.lessons l WHERE l.teacherId = t.id) AS GroupCount,
        (SELECT COUNT(DISTINCT l.subjectId) FROM SCHOOL_MAIN.SchoolManagement.dbo.lessons l WHERE l.teacherId = t.id) AS SubjectCount,
        
        -- Student performance in teacher's groups
        AVG(sa.OverallScore) AS AvgStudentPerformance
    FROM TeacherPerformance tp
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.teachers t ON tp.TeacherID = t.id
    LEFT JOIN SCHOOL_MAIN.SchoolManagement.dbo.groups g ON g.home_teacher_id = t.id
    LEFT JOIN SCHOOL_MAIN.SchoolManagement.dbo.students s ON s.groupId = g.id
    LEFT JOIN StudentAnalytics sa ON s.id = sa.StudentID
    GROUP BY 
        t.id, t.firstName, t.lastName, tp.StudentSatisfaction, 
        tp.ParentSatisfaction, tp.AdministrationSatisfaction, tp.OverallRating
    ORDER BY tp.OverallRating DESC;
    
    -- 5. Top Performing Students
    SELECT TOP 10
        'Top Performing Students' AS ReportSection,
        s.id AS StudentID,
        s.firstName + ' ' + s.lastName AS StudentName,
        gr.id AS GroupID,
        t.firstName + ' ' + t.lastName AS HomeTeacher,
        sa.AcademicScore,
        sa.BehavioralScore,
        sa.AttendanceScore,
        sa.OverallScore,
        sa.Comments
    FROM StudentAnalytics sa
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.students s ON sa.StudentID = s.id
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.groups gr ON s.groupId = gr.id
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.teachers t ON gr.home_teacher_id = t.id
    ORDER BY sa.OverallScore DESC;
    
    -- 6. Students Needing Improvement
    SELECT TOP 10
        'Students Needing Improvement' AS ReportSection,
        s.id AS StudentID,
        s.firstName + ' ' + s.lastName AS StudentName,
        gr.id AS GroupID,
        t.firstName + ' ' + t.lastName AS HomeTeacher,
        sa.AcademicScore,
        sa.BehavioralScore,
        sa.AttendanceScore,
        sa.OverallScore,
        sa.Comments
    FROM StudentAnalytics sa
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.students s ON sa.StudentID = s.id
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.groups gr ON s.groupId = gr.id
    JOIN SCHOOL_MAIN.SchoolManagement.dbo.teachers t ON gr.home_teacher_id = t.id
    ORDER BY sa.OverallScore ASC;
END;
GO

-- Execute the report
EXEC sp_GenerateAnalyticsReport;
GO
```

## 10. Export Data Back to Excel

```sql
-- Create a stored procedure to generate CSV files for Excel
CREATE PROCEDURE sp_ExportToCSV
    @OutputPath NVARCHAR(255) = 'C:\Data\'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create CSV output
    DECLARE @CMD NVARCHAR(4000);
    
    -- 1. Export overall school performance
    SET @CMD = 'bcp "SELECT ''ReportSection'',''AvgAcademicScore'',''AvgBehavioralScore'',''AvgAttendanceScore'',''AvgOverallScore'',''MinOverallScore'',''MaxOverallScore'',''StdDevOverallScore''" queryout "' 
        + @OutputPath + 'SchoolPerformance.csv" -c -t, -T -S ' + @@SERVERNAME;
    EXEC xp_cmdshell @CMD;
    
    SET @CMD = 'bcp "SELECT ''Overall School Performance'', CAST(AVG(AcademicScore) AS NVARCHAR), CAST(AVG(BehavioralScore) AS NVARCHAR), CAST(AVG(AttendanceScore) AS NVARCHAR), CAST(AVG(OverallScore) AS NVARCHAR), CAST(MIN(OverallScore) AS NVARCHAR), CAST(MAX(OverallScore) AS NVARCHAR), CAST(STDEV(OverallScore) AS NVARCHAR) FROM SchoolAnalytics.dbo.StudentAnalytics" queryout "'
        + @OutputPath + 'SchoolPerformance_Data.csv" -c -t, -T -S ' + @@SERVERNAME;
    EXEC xp_cmdshell @CMD;
    
    -- 2. Export group performance
    SET @CMD = 'bcp "SELECT ''GroupID'',''AcademicYear'',''HomeTeacher'',''AvgAcademicScore'',''AvgBehavioralScore'',''AvgAttendanceScore'',''AvgOverallScore'',''StudentCount''" queryout "' 
        + @OutputPath + 'GroupPerformance.csv" -c -t, -T -S ' + @@SERVERNAME;
    EXEC xp_cmdshell @CMD;
    
    SET @CMD = 'bcp "SELECT CAST(gr.id AS NVARCHAR), CAST(y.value AS NVARCHAR), t.firstName + '' '' + t.lastName, CAST(AVG(sa.AcademicScore) AS NVARCHAR), CAST(AVG(sa.BehavioralScore) AS NVARCHAR), CAST(AVG(sa.AttendanceScore) AS NVARCHAR), CAST(AVG(sa.OverallScore) AS NVARCHAR), CAST(COUNT(sa.StudentID) AS NVARCHAR) FROM SchoolAnalytics.dbo.StudentAnalytics sa JOIN SCHOOL_MAIN.SchoolManagement.dbo.students s ON sa.StudentID = s.id JOIN SCHOOL_MAIN.SchoolManagement.dbo.groups gr ON s.groupId = gr.id JOIN SCHOOL_MAIN.SchoolManagement.dbo.years y ON gr.yearId = y.id JOIN SCHOOL_MAIN.SchoolManagement.dbo.teachers t ON gr.home_teacher_id = t.id GROUP BY gr.id, y.value, t.firstName, t.lastName ORDER BY AVG(sa.OverallScore) DESC" queryout "'
        + @OutputPath + 'GroupPerformance_Data.csv" -c -t, -T -S ' + @@SERVERNAME;
    EXEC xp_cmdshell @CMD;
    
    -- 3. Export top students
    SET @CMD = 'bcp "SELECT ''StudentID'',''StudentName'',''GroupID'',''HomeTeacher'',''AcademicScore'',''BehavioralScore'',''AttendanceScore'',''OverallScore'',''Comments''" queryout "' 
        + @OutputPath + 'TopStudents.csv" -c -t, -T -S ' + @@SERVERNAME;
    EXEC xp_cmdshell @CMD;
    
    SET @CMD = 'bcp "SELECT TOP 10 CAST(s.id AS NVARCHAR), s.firstName + '' '' + s.lastName, CAST(gr.id AS NVARCHAR), t.firstName + '' '' + t.lastName, CAST(sa.AcademicScore AS NVARCHAR), CAST(sa.BehavioralScore AS NVARCHAR), CAST(sa.AttendanceScore AS NVARCHAR), CAST(sa.OverallScore AS NVARCHAR), sa.Comments FROM SchoolAnalytics.dbo.StudentAnalytics sa JOIN SCHOOL_MAIN.SchoolManagement.dbo.students s ON sa.StudentID = s.id JOIN SCHOOL_MAIN.SchoolManagement.dbo.groups gr ON s.groupId = gr.id JOIN SCHOOL_MAIN.SchoolManagement.dbo.teachers t ON gr.home_teacher_id = t.id ORDER BY sa.OverallScore DESC" queryout "'
        + @OutputPath + 'TopStudents_Data.csv" -c -t, -T -S ' + @@SERVERNAME;
    EXEC xp_cmdshell @CMD;
    
    PRINT 'CSV files have been exported to ' + @OutputPath;
END;
GO

-- Execute the export procedure
-- Note: You need to have appropriate permissions to run xp_cmdshell
-- EXEC sp_ExportToCSV 'C:\Data\';
```

---

**Next Steps:**
1. Create the Excel file with the structure described in section 1
2. Run the SQL script in section 2 to generate sample data
3. Copy the data to your Excel file and save it
4. Run the configuration scripts in section 3 to set up the Excel linked server
5. Test the queries and views to ensure they work correctly
6. Set up the analytics database and import procedures if needed
7. Run the analytics report procedure to generate comprehensive reports
8. Export the data back to Excel for visual analysis