USE SchoolManagement;
GO

-- Create a distributed view combining data from all sources
CREATE VIEW vw_StudentCompleteProfile AS
SELECT 
    -- Student basic information from MSSQL
    s.id AS StudentId,
    s.firstName,
    s.lastName,
    s.birthday,
    g.value AS Gender,
    gr.id AS GroupId,
    y.value AS AcademicYear,
    
    -- Teacher information from MSSQL
    t.firstName + ' ' + t.lastName AS HomeTeacher,
    
    -- Contract information from Oracle
    c.startDate AS ContractStartDate,
    c.endDate AS ContractEndDate,
    c.monthlyAmount AS MonthlyFee,
    
    -- Payment status from Oracle
    p.total_payments,
    p.total_paid,
    p.total_pending,
    
    -- Remarks count from PostgreSQL
    r.total_remarks,
    r.serious_remarks
FROM students s
JOIN genders g ON s.genderId = g.id
JOIN groups gr ON s.groupId = gr.id
JOIN years y ON gr.yearId = y.id
JOIN teachers t ON gr.home_teacher_id = t.id

-- Left join Oracle contract data
LEFT JOIN (
    SELECT 
        studentId,
        startDate,
        endDate,
        monthlyAmount
    FROM ORACLE_LINK..contracts
) c ON s.id = c.studentId

-- Left join Oracle payment summary
LEFT JOIN (
    SELECT 
        ct.studentId,
        COUNT(p.id) AS total_payments,
        SUM(CASE WHEN p.status = 'PAID' THEN 1 ELSE 0 END) AS total_paid,
        SUM(CASE WHEN p.status = 'PENDING' THEN 1 ELSE 0 END) AS total_pending
    FROM ORACLE_LINK..contracts ct
    LEFT JOIN ORACLE_LINK..payments p ON ct.id = p.contractId
    GROUP BY ct.studentId
) p ON s.id = p.studentId

-- Left join PostgreSQL remarks summary
LEFT JOIN (
    SELECT 
        studentId,
        COUNT(*) AS total_remarks,
        SUM(CASE WHEN severity IN ('SERIOUS', 'CRITICAL') THEN 1 ELSE 0 END) AS serious_remarks
    FROM OPENQUERY(POSTGRES_LINK, 'SELECT studentId, severity FROM remarks.remark') 
    GROUP BY studentId
) r ON s.id = r.studentId;
GO

-- Create a view for financial summary from Oracle
CREATE VIEW vw_FinancialSummary AS
SELECT 
    s.id AS StudentId,
    s.firstName + ' ' + s.lastName AS StudentName,
    c.monthlyAmount,
    c.startDate,
    c.endDate,
    DATEDIFF(MONTH, c.startDate, ISNULL(c.endDate, GETDATE())) AS ContractMonths,
    ps.total_due,
    ps.total_paid,
    ps.total_outstanding
FROM students s
JOIN (
    SELECT 
        ct.studentId,
        ct.monthlyAmount,
        ct.startDate,
        ct.endDate,
        SUM(p.amount) AS total_due,
        SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) AS total_paid,
        SUM(CASE WHEN p.status != 'PAID' THEN p.amount ELSE 0 END) AS total_outstanding
    FROM ORACLE_LINK..contracts ct
    LEFT JOIN ORACLE_LINK..payments p ON ct.id = p.contractId
    GROUP BY ct.studentId, ct.monthlyAmount, ct.startDate, ct.endDate
) ps ON s.id = ps.studentId
JOIN ORACLE_LINK..contracts c ON s.id = c.studentId;
GO

-- Create a view for behavioral analysis from PostgreSQL
CREATE VIEW vw_BehavioralSummary AS
SELECT 
    s.id AS StudentId,
    s.firstName + ' ' + s.lastName AS StudentName,
    rs.total_remarks,
    rs.academic_remarks,
    rs.behavioral_remarks,
    rs.attendance_remarks,
    rs.critical_remarks,
    rs.latest_remark_date
FROM students s
LEFT JOIN (
    SELECT 
        studentId,
        COUNT(*) AS total_remarks,
        SUM(CASE WHEN category = 'ACADEMIC' THEN 1 ELSE 0 END) AS academic_remarks,
        SUM(CASE WHEN category = 'BEHAVIORAL' THEN 1 ELSE 0 END) AS behavioral_remarks,
        SUM(CASE WHEN category = 'ATTENDANCE' THEN 1 ELSE 0 END) AS attendance_remarks,
        SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_remarks,
        MAX(created_date) AS latest_remark_date
    FROM OPENQUERY(POSTGRES_LINK, '
        SELECT studentId, category, severity, created_date 
        FROM remarks.remark 
        WHERE created_date >= CURRENT_DATE - INTERVAL ''90 days''
    ')
    GROUP BY studentId
) rs ON s.id = rs.studentId;
GO