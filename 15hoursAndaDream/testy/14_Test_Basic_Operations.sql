USE SchoolDB;
GO

-- Test 1: Insert and retrieve students
INSERT INTO students (groupId, firstName, lastName, birthday, genderId)
VALUES (1, 'Test', 'Student', '2010-01-01', 1);

DECLARE @NewStudentId INT = SCOPE_IDENTITY();
SELECT 'Created new student with ID: ' + CAST(@NewStudentId AS VARCHAR(10));

SELECT * FROM students WHERE id = @NewStudentId;

-- Test 2: Teacher assignments
SELECT 
    t.firstName + ' ' + t.lastName as TeacherName,
    COUNT(l.id) as TotalLessons,
    STRING_AGG(s.longName, ', ') as Subjects
FROM teachers t
LEFT JOIN lessons l ON t.id = l.teacherId
LEFT JOIN subjects s ON l.subjectId = s.id
GROUP BY t.id, t.firstName, t.lastName;

-- Test 3: Grade calculations
SELECT 
    s.firstName + ' ' + s.lastName as StudentName,
    COUNT(m.id) as TotalMarks,
    AVG(CAST(m.value AS FLOAT)) as AverageGrade,
    MIN(m.value) as LowestGrade,
    MAX(m.value) as HighestGrade
FROM students s
LEFT JOIN marks m ON s.id = m.studentId
GROUP BY s.id, s.firstName, s.lastName
HAVING COUNT(m.id) > 0;

-- Test 4: Attendance tracking
SELECT 
    s.firstName + ' ' + s.lastName as StudentName,
    COUNT(ats.id) as TotalAttendanceRecords,
    SUM(CASE WHEN ats.present = 1 THEN 1 ELSE 0 END) as DaysPresent,
    COUNT(ats.id) - SUM(CASE WHEN ats.present = 1 THEN 1 ELSE 0 END) as DaysAbsent,
    CAST(AVG(CAST(ats.present AS FLOAT)) * 100 AS DECIMAL(5,2)) as AttendanceRate
FROM students s
LEFT JOIN attendance_student ats ON s.id = ats.studentId
GROUP BY s.id, s.firstName, s.lastName
HAVING COUNT(ats.id) > 0;

-- Test 5: Complex joins
SELECT 
    s.firstName + ' ' + s.lastName as StudentName,
    g.value as Gender,
    y.value as SchoolYear,
    p.firstName + ' ' + p.lastName as ParentName,
    p.email as ParentEmail,
    COUNT(DISTINCT m.id) as TotalGrades,
    COUNT(DISTINCT l.id) as TotalLessons
FROM students s
LEFT JOIN genders g ON s.genderId = g.id
LEFT JOIN groups gr ON s.groupId = gr.id
LEFT JOIN years y ON gr.yearId = y.id
LEFT JOIN parents_students ps ON s.id = ps.studentId
LEFT JOIN parents p ON ps.parentId = p.id
LEFT JOIN marks m ON s.id = m.studentId
LEFT JOIN lessons l ON gr.id = l.groupId
GROUP BY s.id, s.firstName, s.lastName, g.value, y.value, p.firstName, p.lastName, p.email;

