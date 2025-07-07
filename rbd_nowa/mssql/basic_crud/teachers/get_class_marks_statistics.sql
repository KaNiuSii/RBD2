CREATE OR ALTER PROCEDURE sp_GetClassMarksStatistics
    @GroupId INT,
    @SubjectId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        s.id as StudentId,
        s.firstName + ' ' + s.lastName as StudentName,
        sub.shortName as SubjectCode,
        COUNT(m.id) as TotalMarks,
        AVG(CAST(m.value as FLOAT)) as AverageGrade,
        MIN(m.value) as MinGrade,
        MAX(m.value) as MaxGrade
    FROM students s
    LEFT JOIN marks m ON s.id = m.studentId
    LEFT JOIN subjects sub ON m.subjectId = sub.id
    WHERE s.groupId = @GroupId
        AND (@SubjectId IS NULL OR m.subjectId = @SubjectId)
    GROUP BY s.id, s.firstName, s.lastName, sub.id, sub.shortName
    ORDER BY s.lastName, s.firstName, sub.shortName;

    SELECT 
        sub.shortName as SubjectCode,
        sub.longName as SubjectName,
        COUNT(m.id) as TotalMarks,
        AVG(CAST(m.value as FLOAT)) as ClassAverage,
        MIN(m.value) as LowestGrade,
        MAX(m.value) as HighestGrade,
        COUNT(DISTINCT m.studentId) as StudentsWithMarks
    FROM marks m
    INNER JOIN subjects sub ON m.subjectId = sub.id
    INNER JOIN students s ON m.studentId = s.id
    WHERE s.groupId = @GroupId
        AND (@SubjectId IS NULL OR m.subjectId = @SubjectId)
    GROUP BY sub.id, sub.shortName, sub.longName
    ORDER BY sub.shortName;
END;
GO