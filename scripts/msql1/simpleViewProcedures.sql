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