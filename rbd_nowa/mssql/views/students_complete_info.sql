
USE SchoolDB;
GO

CREATE OR ALTER VIEW vw_StudentCompleteInfo AS
SELECT 
    s.id as StudentId,
    s.firstName + ' ' + s.lastName as StudentName,
    s.birthday,
    g.value as Gender,
    y.value as SchoolYear,
    p.firstName + ' ' + p.lastName as ParentName,
    p.email as ParentEmail,
    p.phoneNumber as ParentPhone
FROM students s
    INNER JOIN genders g ON s.genderId = g.id
    INNER JOIN groups gr ON s.groupId = gr.id
    INNER JOIN years y ON gr.yearId = y.id
    INNER JOIN parents_students ps ON s.id = ps.studentId
    INNER JOIN parents p ON ps.parentId = p.id;
GO

SELECT * FROM vw_StudentCompleteInfo;