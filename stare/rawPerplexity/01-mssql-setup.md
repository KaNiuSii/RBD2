# MSSQL Main Database Setup Script

## 1. Database Creation and Configuration

```sql
-- Create the main school management database
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SchoolManagement')
BEGIN
    ALTER DATABASE SchoolManagement SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SchoolManagement;
END
GO

CREATE DATABASE SchoolManagement
ON 
( NAME = 'SchoolManagement_Data',
  FILENAME = 'C:\Database\SchoolManagement_Data.mdf',
  SIZE = 1GB,
  MAXSIZE = 10GB,
  FILEGROWTH = 100MB )
LOG ON 
( NAME = 'SchoolManagement_Log',
  FILENAME = 'C:\Database\SchoolManagement_Log.ldf',
  SIZE = 100MB,
  MAXSIZE = 1GB,
  FILEGROWTH = 10MB );
GO

USE SchoolManagement;
GO
```

## 2. Create Tables with Proper Relationships

```sql
-- Create Gender lookup table
CREATE TABLE genders (
    id INT IDENTITY(1,1) PRIMARY KEY,
    value NVARCHAR(20) NOT NULL UNIQUE
);

-- Create Years table
CREATE TABLE years (
    id INT IDENTITY(1,1) PRIMARY KEY,
    value INT NOT NULL UNIQUE
);

-- Create Teachers table
CREATE TABLE teachers (
    id INT IDENTITY(1,1) PRIMARY KEY,
    firstName NVARCHAR(50) NOT NULL,
    lastName NVARCHAR(50) NOT NULL,
    birthday DATE NOT NULL,
    phoneNumber NVARCHAR(20),
    email NVARCHAR(100),
    additionalInfo NVARCHAR(500)
);

-- Create Groups table
CREATE TABLE groups (
    id INT IDENTITY(1,1) PRIMARY KEY,
    yearId INT NOT NULL,
    home_teacher_id INT NOT NULL,
    FOREIGN KEY (yearId) REFERENCES years(id),
    FOREIGN KEY (home_teacher_id) REFERENCES teachers(id)
);

-- Create Students table
CREATE TABLE students (
    id INT IDENTITY(1,1) PRIMARY KEY,
    groupId INT NOT NULL,
    firstName NVARCHAR(50) NOT NULL,
    lastName NVARCHAR(50) NOT NULL,
    birthday DATE NOT NULL,
    genderId INT NOT NULL,
    FOREIGN KEY (groupId) REFERENCES groups(id),
    FOREIGN KEY (genderId) REFERENCES genders(id)
);

-- Create Parents table
CREATE TABLE parents (
    id INT IDENTITY(1,1) PRIMARY KEY,
    firstName NVARCHAR(50) NOT NULL,
    lastName NVARCHAR(50) NOT NULL,
    phoneNumber NVARCHAR(20),
    email NVARCHAR(100)
);

-- Create Parents-Students relationship table
CREATE TABLE parents_students (
    id INT IDENTITY(1,1) PRIMARY KEY,
    parentId INT NOT NULL,
    studentId INT NOT NULL,
    FOREIGN KEY (parentId) REFERENCES parents(id),
    FOREIGN KEY (studentId) REFERENCES students(id),
    UNIQUE(parentId, studentId)
);

-- Create Classrooms table
CREATE TABLE classrooms (
    id INT IDENTITY(1,1) PRIMARY KEY,
    location NVARCHAR(100) NOT NULL
);

-- Create Subjects table
CREATE TABLE subjects (
    id INT IDENTITY(1,1) PRIMARY KEY,
    shortName NVARCHAR(10) NOT NULL,
    longName NVARCHAR(100) NOT NULL
);

-- Create Hours table
CREATE TABLE hours (
    id INT IDENTITY(1,1) PRIMARY KEY,
    start_hour INT NOT NULL CHECK (start_hour >= 0 AND start_hour <= 23),
    start_minutes INT NOT NULL CHECK (start_minutes >= 0 AND start_minutes <= 59),
    end_hour INT NOT NULL CHECK (end_hour >= 0 AND end_hour <= 23),
    end_minutes INT NOT NULL CHECK (end_minutes >= 0 AND end_minutes <= 59)
);

-- Create Days table
CREATE TABLE days (
    id INT IDENTITY(1,1) PRIMARY KEY,
    value NVARCHAR(20) NOT NULL UNIQUE
);

-- Create Lessons table
CREATE TABLE lessons (
    id INT IDENTITY(1,1) PRIMARY KEY,
    teacherId INT NOT NULL,
    subjectId INT NOT NULL,
    groupId INT NOT NULL,
    hourId INT NOT NULL,
    classroomId INT NOT NULL,
    dayId INT NOT NULL,
    FOREIGN KEY (teacherId) REFERENCES teachers(id),
    FOREIGN KEY (subjectId) REFERENCES subjects(id),
    FOREIGN KEY (groupId) REFERENCES groups(id),
    FOREIGN KEY (hourId) REFERENCES hours(id),
    FOREIGN KEY (classroomId) REFERENCES classrooms(id),
    FOREIGN KEY (dayId) REFERENCES days(id)
);

-- Create Marks table
CREATE TABLE marks (
    id INT IDENTITY(1,1) PRIMARY KEY,
    subjectId INT NOT NULL,
    studentId INT NOT NULL,
    value INT NOT NULL CHECK (value >= 1 AND value <= 6),
    comment NVARCHAR(500),
    weight INT DEFAULT 1 CHECK (weight > 0),
    date_created DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (subjectId) REFERENCES subjects(id),
    FOREIGN KEY (studentId) REFERENCES students(id)
);

-- Create Attendances table
CREATE TABLE attendances (
    id INT IDENTITY(1,1) PRIMARY KEY,
    datexd DATETIME NOT NULL,
    lessonId INT NOT NULL,
    FOREIGN KEY (lessonId) REFERENCES lessons(id)
);

-- Create Attendance_Student table
CREATE TABLE attendance_student (
    id INT IDENTITY(1,1) PRIMARY KEY,
    attendanceId INT NOT NULL,
    studentId INT NOT NULL,
    present BIT NOT NULL DEFAULT 1,
    FOREIGN KEY (attendanceId) REFERENCES attendances(id),
    FOREIGN KEY (studentId) REFERENCES students(id),
    UNIQUE(attendanceId, studentId)
);
```

## 3. Insert Sample Data

```sql
-- Insert lookup data
INSERT INTO genders (value) VALUES ('Male'), ('Female'), ('Other');

INSERT INTO years (value) VALUES (2023), (2024), (2025);

INSERT INTO days (value) VALUES 
('Monday'), ('Tuesday'), ('Wednesday'), ('Thursday'), ('Friday');

-- Insert Hours (8 periods)
INSERT INTO hours (start_hour, start_minutes, end_hour, end_minutes) VALUES
(8, 0, 8, 45),   -- Period 1
(8, 55, 9, 40),  -- Period 2
(9, 50, 10, 35), -- Period 3
(10, 55, 11, 40), -- Period 4
(11, 50, 12, 35), -- Period 5
(13, 30, 14, 15), -- Period 6
(14, 25, 15, 10), -- Period 7
(15, 20, 16, 5);  -- Period 8

-- Insert Subjects
INSERT INTO subjects (shortName, longName) VALUES
('MATH', 'Mathematics'),
('ENG', 'English Language'),
('PHYS', 'Physics'),
('CHEM', 'Chemistry'),
('BIO', 'Biology'),
('HIST', 'History'),
('GEO', 'Geography'),
('PE', 'Physical Education'),
('ART', 'Art'),
('MUS', 'Music');

-- Insert Classrooms
INSERT INTO classrooms (location) VALUES
('Building A - Room 101'), ('Building A - Room 102'), ('Building A - Room 103'),
('Building B - Room 201'), ('Building B - Room 202'), ('Building B - Room 203'),
('Building C - Room 301'), ('Building C - Room 302'), ('Building C - Room 303'),
('Gymnasium'), ('Art Studio'), ('Music Room'), ('Laboratory 1'), ('Laboratory 2');

-- Insert Teachers with realistic data
INSERT INTO teachers (firstName, lastName, birthday, phoneNumber, email, additionalInfo) VALUES
('John', 'Smith', '1975-03-15', '+1234567890', 'j.smith@school.edu', 'Mathematics Department Head'),
('Sarah', 'Johnson', '1980-07-22', '+1234567891', 's.johnson@school.edu', 'English Department'),
('Michael', 'Brown', '1978-11-08', '+1234567892', 'm.brown@school.edu', 'Science Department'),
('Emily', 'Davis', '1982-04-12', '+1234567893', 'e.davis@school.edu', 'History Department'),
('Robert', 'Wilson', '1976-09-30', '+1234567894', 'r.wilson@school.edu', 'Physical Education'),
('Lisa', 'Taylor', '1985-01-18', '+1234567895', 'l.taylor@school.edu', 'Art Department'),
('David', 'Anderson', '1979-06-25', '+1234567896', 'd.anderson@school.edu', 'Music Department'),
('Jennifer', 'Thomas', '1983-12-03', '+1234567897', 'j.thomas@school.edu', 'Chemistry Specialist'),
('Mark', 'Jackson', '1977-05-14', '+1234567898', 'm.jackson@school.edu', 'Physics Department'),
('Amanda', 'White', '1981-08-27', '+1234567899', 'a.white@school.edu', 'Biology Department');

-- Insert Groups (Classes)
INSERT INTO groups (yearId, home_teacher_id) VALUES
(1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7),  -- Year 2023
(2, 8), (2, 9), (2, 10), (2, 1), (2, 2), (2, 3), (2, 4), -- Year 2024
(3, 5), (3, 6), (3, 7), (3, 8), (3, 9), (3, 10);         -- Year 2025

-- Generate sample students (simplified version - you can expand this)
DECLARE @i INT = 1;
DECLARE @firstName NVARCHAR(50);
DECLARE @lastName NVARCHAR(50);
DECLARE @firstNames TABLE (name NVARCHAR(50));
DECLARE @lastNames TABLE (name NVARCHAR(50));

INSERT INTO @firstNames VALUES 
('James'), ('Mary'), ('John'), ('Patricia'), ('Robert'), ('Jennifer'), ('Michael'), ('Linda'),
('William'), ('Elizabeth'), ('David'), ('Barbara'), ('Richard'), ('Susan'), ('Joseph'), ('Jessica'),
('Thomas'), ('Sarah'), ('Christopher'), ('Karen'), ('Charles'), ('Nancy'), ('Daniel'), ('Lisa'),
('Matthew'), ('Betty'), ('Anthony'), ('Helen'), ('Mark'), ('Sandra');

INSERT INTO @lastNames VALUES
('Smith'), ('Johnson'), ('Williams'), ('Brown'), ('Jones'), ('Garcia'), ('Miller'), ('Davis'),
('Rodriguez'), ('Martinez'), ('Hernandez'), ('Lopez'), ('Gonzalez'), ('Wilson'), ('Anderson'), ('Thomas'),
('Taylor'), ('Moore'), ('Jackson'), ('Martin'), ('Lee'), ('Perez'), ('Thompson'), ('White'),
('Harris'), ('Sanchez'), ('Clark'), ('Ramirez'), ('Lewis'), ('Robinson');

-- Insert Students
WHILE @i <= 100
BEGIN
    SELECT TOP 1 @firstName = name FROM @firstNames ORDER BY NEWID();
    SELECT TOP 1 @lastName = name FROM @lastNames ORDER BY NEWID();
    
    INSERT INTO students (groupId, firstName, lastName, birthday, genderId)
    VALUES (
        (@i % 20) + 1,  -- Distribute across groups
        @firstName,
        @lastName,
        DATEADD(year, -16 - (@i % 4), GETDATE()),  -- Ages 16-19
        (@i % 3) + 1    -- Random gender
    );
    
    SET @i = @i + 1;
END;

-- Insert Parents
INSERT INTO parents (firstName, lastName, phoneNumber, email)
SELECT 
    CASE WHEN ROW_NUMBER() OVER (ORDER BY s.id) % 2 = 1 THEN 'Father_' + s.firstName ELSE 'Mother_' + s.firstName END,
    s.lastName,
    '+1234' + RIGHT('000000' + CAST(s.id AS VARCHAR), 6),
    LOWER(s.firstName + '.' + s.lastName + '@email.com')
FROM students s;

-- Link parents to students
INSERT INTO parents_students (parentId, studentId)
SELECT p.id, s.id
FROM parents p
JOIN students s ON p.lastName = s.lastName;
```

## 4. Create Initial Views and Stored Procedures

```sql
-- Create a comprehensive student view
CREATE VIEW vw_StudentDetails AS
SELECT 
    s.id AS StudentId,
    s.firstName + ' ' + s.lastName AS StudentName,
    s.birthday,
    DATEDIFF(YEAR, s.birthday, GETDATE()) AS Age,
    g.value AS Gender,
    gr.id AS GroupId,
    y.value AS AcademicYear,
    t.firstName + ' ' + t.lastName AS HomeTeacher,
    t.email AS TeacherEmail
FROM students s
JOIN genders g ON s.genderId = g.id
JOIN groups gr ON s.groupId = gr.id
JOIN years y ON gr.yearId = y.id
JOIN teachers t ON gr.home_teacher_id = t.id;
GO

-- Create a stored procedure for student enrollment
CREATE PROCEDURE sp_EnrollStudent
    @firstName NVARCHAR(50),
    @lastName NVARCHAR(50),
    @birthday DATE,
    @genderId INT,
    @groupId INT,
    @parentFirstName NVARCHAR(50),
    @parentLastName NVARCHAR(50),
    @parentPhone NVARCHAR(20),
    @parentEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    
    DECLARE @studentId INT, @parentId INT;
    
    TRY
        -- Insert student
        INSERT INTO students (firstName, lastName, birthday, genderId, groupId)
        VALUES (@firstName, @lastName, @birthday, @genderId, @groupId);
        
        SET @studentId = SCOPE_IDENTITY();
        
        -- Insert parent
        INSERT INTO parents (firstName, lastName, phoneNumber, email)
        VALUES (@parentFirstName, @parentLastName, @parentPhone, @parentEmail);
        
        SET @parentId = SCOPE_IDENTITY();
        
        -- Link parent to student
        INSERT INTO parents_students (parentId, studentId)
        VALUES (@parentId, @studentId);
        
        COMMIT TRANSACTION;
        SELECT @studentId AS NewStudentId;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Create stored procedure for grade management
CREATE PROCEDURE sp_AddGrade
    @studentId INT,
    @subjectId INT,
    @value INT,
    @comment NVARCHAR(500) = NULL,
    @weight INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate inputs
    IF NOT EXISTS (SELECT 1 FROM students WHERE id = @studentId)
        THROW 50001, 'Student not found', 1;
        
    IF NOT EXISTS (SELECT 1 FROM subjects WHERE id = @subjectId)
        THROW 50002, 'Subject not found', 1;
        
    IF @value < 1 OR @value > 6
        THROW 50003, 'Grade value must be between 1 and 6', 1;
    
    INSERT INTO marks (studentId, subjectId, value, comment, weight)
    VALUES (@studentId, @subjectId, @value, @comment, @weight);
    
    SELECT SCOPE_IDENTITY() AS NewGradeId;
END;
GO

-- Create function to calculate student average
CREATE FUNCTION fn_CalculateStudentAverage(@studentId INT, @subjectId INT = NULL)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @average DECIMAL(5,2);
    
    SELECT @average = 
        CAST(SUM(CAST(value AS DECIMAL) * weight) AS DECIMAL) / 
        CAST(SUM(weight) AS DECIMAL)
    FROM marks 
    WHERE studentId = @studentId 
    AND (@subjectId IS NULL OR subjectId = @subjectId);
    
    RETURN ISNULL(@average, 0);
END;
GO
```

## 5. Create Indexes for Performance

```sql
-- Create indexes for better performance
CREATE INDEX IX_Students_GroupId ON students(groupId);
CREATE INDEX IX_Students_GenderId ON students(genderId);
CREATE INDEX IX_Marks_StudentId ON marks(studentId);
CREATE INDEX IX_Marks_SubjectId ON marks(subjectId);
CREATE INDEX IX_Lessons_TeacherId ON lessons(teacherId);
CREATE INDEX IX_Lessons_GroupId ON lessons(groupId);
CREATE INDEX IX_Attendance_LessonId ON attendances(lessonId);
CREATE INDEX IX_AttendanceStudent_StudentId ON attendance_student(studentId);
```

## 6. Enable Features for Distributed Operations

```sql
-- Enable advanced features needed for distributed operations
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Enable Ad Hoc Distributed Queries
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;

-- Enable Distributed Transaction Coordinator
EXEC sp_configure 'remote access', 1;
RECONFIGURE;

-- Enable CLR Integration (if needed)
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
```

## 7. Create Additional Sample Data

```sql
-- Add more sample data for testing
DECLARE @lessonCounter INT = 1;
DECLARE @groupId INT, @teacherId INT, @subjectId INT, @dayId INT, @hourId INT, @classroomId INT;

-- Create sample lesson schedule
WHILE @lessonCounter <= 50
BEGIN
    SET @groupId = (@lessonCounter % 20) + 1;
    SET @teacherId = (@lessonCounter % 10) + 1;
    SET @subjectId = (@lessonCounter % 10) + 1;
    SET @dayId = (@lessonCounter % 5) + 1;
    SET @hourId = (@lessonCounter % 8) + 1;
    SET @classroomId = (@lessonCounter % 14) + 1;
    
    INSERT INTO lessons (teacherId, subjectId, groupId, hourId, classroomId, dayId)
    VALUES (@teacherId, @subjectId, @groupId, @hourId, @classroomId, @dayId);
    
    SET @lessonCounter = @lessonCounter + 1;
END;

-- Generate sample grades
DECLARE @gradeCounter INT = 1;
DECLARE @studentId INT, @grade INT;

WHILE @gradeCounter <= 200
BEGIN
    SET @studentId = (@gradeCounter % 100) + 1;
    SET @subjectId = (@gradeCounter % 10) + 1;
    SET @grade = (ABS(CHECKSUM(NEWID())) % 5) + 2; -- Grades 2-6
    
    INSERT INTO marks (studentId, subjectId, value, comment, weight)
    VALUES (@studentId, @subjectId, @grade, 'Sample grade', 1);
    
    SET @gradeCounter = @gradeCounter + 1;
END;

PRINT 'MSSQL Main Database Setup Complete!';
PRINT 'Database: SchoolManagement';
PRINT 'Tables Created: ' + CAST((SELECT COUNT(*) FROM sys.tables) AS VARCHAR);
PRINT 'Students: ' + CAST((SELECT COUNT(*) FROM students) AS VARCHAR);
PRINT 'Teachers: ' + CAST((SELECT COUNT(*) FROM teachers) AS VARCHAR);
PRINT 'Lessons: ' + CAST((SELECT COUNT(*) FROM lessons) AS VARCHAR);
PRINT 'Grades: ' + CAST((SELECT COUNT(*) FROM marks) AS VARCHAR);
```

---

**Next Steps:**
1. Run this script on your main MSSQL server
2. Verify all tables are created successfully
3. Check that sample data is populated
4. Test the stored procedures and views
5. Proceed with the Oracle setup script