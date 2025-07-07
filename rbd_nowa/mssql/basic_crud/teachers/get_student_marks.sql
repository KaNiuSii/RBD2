CREATE OR ALTER PROCEDURE sp_GetStudentMarks
    @StudentId INT,
    @SubjectId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        m.id,
        sub.shortName as SubjectCode,
        sub.longName as SubjectName,
        m.value,
        m.comment,
        m.weight,
        GETDATE() as DateAdded
    FROM marks m
    INNER JOIN subjects sub ON m.subjectId = sub.id
    WHERE m.studentId = @StudentId
        AND (@SubjectId IS NULL OR m.subjectId = @SubjectId)
    ORDER BY sub.shortName, m.id;

    SELECT 
        sub.shortName as SubjectCode,
        sub.longName as SubjectName,
        COUNT(m.id) as TotalMarks,
        AVG(CAST(m.value as FLOAT)) as SimpleAverage,
        SUM(CAST(m.value * m.weight as FLOAT)) / SUM(m.weight) as WeightedAverage,
        MIN(m.value) as MinMark,
        MAX(m.value) as MaxMark
    FROM marks m
    INNER JOIN subjects sub ON m.subjectId = sub.id
    WHERE m.studentId = @StudentId
        AND (@SubjectId IS NULL OR m.subjectId = @SubjectId)
    GROUP BY sub.id, sub.shortName, sub.longName
    ORDER BY sub.shortName;
END;
GO