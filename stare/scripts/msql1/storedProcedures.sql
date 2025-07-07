-- Procedure to get complete student information from all databases
CREATE PROCEDURE sp_GetStudentCompleteInfo
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Student basic information
    SELECT 
        'Student Information' AS Section,
        s.id,
        s.firstName + ' ' + s.lastName AS FullName,
        s.birthday,
        DATEDIFF(YEAR, s.birthday, GETDATE()) AS Age,
        g.value AS Gender,
        gr.id AS GroupId,
        y.value AS AcademicYear,
        t.firstName + ' ' + t.lastName AS HomeTeacher
    FROM students s
    JOIN genders g ON s.genderId = g.id
    JOIN groups gr ON s.groupId = gr.id
    JOIN years y ON gr.yearId = y.id
    JOIN teachers t ON gr.home_teacher_id = t.id
    WHERE s.id = @StudentId;
    
    -- Contract information from Oracle
    SELECT 
        'Contract Information' AS Section,
        c.startDate,
        c.endDate,
        c.monthlyAmount,
        DATEDIFF(MONTH, c.startDate, ISNULL(c.endDate, GETDATE())) AS ContractDurationMonths
    FROM ORACLE_LINK..contracts c
    WHERE c.studentId = @StudentId;
    
    -- Payment summary from Oracle
    SELECT 
        'Payment Summary' AS Section,
        COUNT(*) AS TotalPayments,
        SUM(CASE WHEN status = 'PAID' THEN 1 ELSE 0 END) AS PaidPayments,
        SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) AS PendingPayments,
        SUM(CASE WHEN status = 'OVERDUE' THEN 1 ELSE 0 END) AS OverduePayments,
        SUM(amount) AS TotalAmount,
        SUM(CASE WHEN status = 'PAID' THEN amount ELSE 0 END) AS PaidAmount,
        SUM(CASE WHEN status != 'PAID' THEN amount ELSE 0 END) AS OutstandingAmount
    FROM ORACLE_LINK..contracts c
    JOIN ORACLE_LINK..payments p ON c.id = p.contractId
    WHERE c.studentId = @StudentId;
    
    -- Recent remarks from PostgreSQL
    SELECT 
        'Recent Remarks' AS Section,
        studentId,
        teacherId,
        value AS RemarkText,
        severity,
        category,
        created_date
    FROM OPENQUERY(POSTGRES_LINK, 'SELECT studentId, teacherId, value, severity, category, created_date FROM remarks.remark WHERE studentId = ' + CAST(@StudentId AS VARCHAR(10)) + ' ORDER BY created_date DESC LIMIT 10');
END;
GO

-- Procedure to synchronize data across databases
CREATE PROCEDURE sp_SynchronizeStudentData
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    
    TRY
        -- Verify student exists in main database
        IF NOT EXISTS (SELECT 1 FROM students WHERE id = @StudentId)
        BEGIN
            RAISERROR('Student with ID %d does not exist in main database', 16, 1, @StudentId);
            RETURN;
        END
        
        -- Get student information
        DECLARE @StudentName NVARCHAR(100);
        SELECT @StudentName = firstName + ' ' + lastName 
        FROM students 
        WHERE id = @StudentId;
        
        -- Log synchronization in remarks system
        DECLARE @RemarkText NVARCHAR(500) = 'Data synchronization performed for student: ' + @StudentName;
        
        EXEC POSTGRES_LINK..pg_proc('remarks.add_remark', @StudentId, 1, @RemarkText, 'INFO', 'GENERAL');
        
        COMMIT TRANSACTION;
        
        PRINT 'Data synchronization completed for student ID: ' + CAST(@StudentId AS VARCHAR(10));
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO