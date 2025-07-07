CREATE OR ALTER PROCEDURE sp_GetStudentsByGroup
    @GroupId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.id,
        s.firstName + ' ' + s.lastName as FullName,
        s.birthday,
        DATEDIFF(YEAR, s.birthday, GETDATE()) as Age,
        g.value as Gender,
        COUNT(m.id) as TotalMarks,
        AVG(CAST(m.value as FLOAT)) as AverageGrade
    FROM students s
    LEFT JOIN genders g ON s.genderId = g.id
    LEFT JOIN marks m ON s.id = m.studentId
    WHERE s.groupId = @GroupId
    GROUP BY s.id, s.firstName, s.lastName, s.birthday, g.value
    ORDER BY s.lastName, s.firstName;
END;
GO