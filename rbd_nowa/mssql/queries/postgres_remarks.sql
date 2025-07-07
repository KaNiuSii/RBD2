SELECT *
FROM OPENQUERY(POSTGRES_REMARKS,
    'SELECT 
        r.studentId,
        r.teacherId,
        COUNT(*) as RemarkCount,
        MAX(r.created_date) as LastRemarkDate
     FROM remarks_main.remark r
     GROUP BY r.studentId, r.teacherId
     ORDER BY r.studentId, r.teacherId') AS PostgresRemarksData;