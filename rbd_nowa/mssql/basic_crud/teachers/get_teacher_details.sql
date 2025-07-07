CREATE OR ALTER PROCEDURE sp_GetTeacherDetails
    @TeacherId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        t.id,
        t.firstName,
        t.lastName,
        t.birthday,
        t.phoneNumber,
        t.email,
        t.additionalInfo,
        COUNT(DISTINCT l.id) as TotalLessons,
        COUNT(DISTINCT l.groupId) as GroupsTeaching,
        COUNT(DISTINCT l.subjectId) as SubjectsTeaching
    FROM teachers t
    LEFT JOIN lessons l ON t.id = l.teacherId
    WHERE t.id = @TeacherId
    GROUP BY t.id, t.firstName, t.lastName, t.birthday, t.phoneNumber, t.email, t.additionalInfo;

    SELECT 
        g.id as GroupId,
        y.value as SchoolYear,
        COUNT(s.id) as StudentCount
    FROM groups g
    INNER JOIN years y ON g.yearId = y.id
    LEFT JOIN students s ON g.id = s.groupId
    WHERE g.home_teacher_id = @TeacherId
    GROUP BY g.id, y.value;

    SELECT 
        l.id as LessonId,
        sub.shortName + ' - ' + sub.longName as Subject,
        d.value as Day,
        h.start_hour, h.start_minutes, h.end_hour, h.end_minutes,
        c.location as Classroom,
        y.value as SchoolYear
    FROM lessons l
    INNER JOIN subjects sub ON l.subjectId = sub.id
    INNER JOIN days d ON l.dayId = d.id
    INNER JOIN hours h ON l.hourId = h.id
    INNER JOIN classrooms c ON l.classroomId = c.id
    INNER JOIN groups g ON l.groupId = g.id
    INNER JOIN years y ON g.yearId = y.id
    WHERE l.teacherId = @TeacherId
    ORDER BY d.id, h.start_hour, h.start_minutes;
END;
GO