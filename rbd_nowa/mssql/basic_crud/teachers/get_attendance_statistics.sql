CREATE OR ALTER PROCEDURE sp_GetAttendanceStatistics
    @StudentId INT = NULL,
    @GroupId INT = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate IS NULL SET @StartDate = DATEADD(MONTH, -1, GETDATE());
    IF @EndDate IS NULL SET @EndDate = GETDATE();

    SELECT 
        s.id as StudentId,
        s.firstName + ' ' + s.lastName as StudentName,
        g.id as GroupId,
        COUNT(ats.id) as TotalSessions,
        SUM(CASE WHEN ats.present = 1 THEN 1 ELSE 0 END) as PresentSessions,
        SUM(CASE WHEN ats.present = 0 THEN 1 ELSE 0 END) as AbsentSessions,
        CAST(
            (SUM(CASE WHEN ats.present = 1 THEN 1 ELSE 0 END) * 100.0) / 
            NULLIF(COUNT(ats.id), 0) 
            as DECIMAL(5,2)
        ) as AttendancePercentage
    FROM students s
    INNER JOIN groups g ON s.groupId = g.id
    LEFT JOIN attendance_student ats ON s.id = ats.studentId
    LEFT JOIN attendances a ON ats.attendanceId = a.id
    WHERE 
        (@StudentId IS NULL OR s.id = @StudentId)
        AND (@GroupId IS NULL OR s.groupId = @GroupId)
        AND (a.dateTimeChecked IS NULL OR 
             (CAST(a.dateTimeChecked as DATE) BETWEEN @StartDate AND @EndDate))
    GROUP BY s.id, s.firstName, s.lastName, g.id
    ORDER BY s.lastName, s.firstName;
END;
GO