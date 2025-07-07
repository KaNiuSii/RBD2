CREATE OR ALTER PROCEDURE sp_GetStudentById
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.id,
        s.firstName,
        s.lastName,
        s.birthday,
        DATEDIFF(YEAR, s.birthday, GETDATE()) as Age,
        g.value as Gender,
        gr.id as GroupId,
        y.value as SchoolYear,
        t.firstName + ' ' + t.lastName as HomeTeacher
    FROM students s
    LEFT JOIN genders g ON s.genderId = g.id
    INNER JOIN groups gr ON s.groupId = gr.id
    INNER JOIN years y ON gr.yearId = y.id
    INNER JOIN teachers t ON gr.home_teacher_id = t.id
    WHERE s.id = @StudentId;

    -- Get parents information
    SELECT 
        p.id,
        p.firstName,
        p.lastName,
        p.phoneNumber,
        p.email
    FROM parents p
    INNER JOIN parents_students ps ON p.id = ps.parentId
    WHERE ps.studentId = @StudentId;
END;
GO