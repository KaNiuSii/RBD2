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