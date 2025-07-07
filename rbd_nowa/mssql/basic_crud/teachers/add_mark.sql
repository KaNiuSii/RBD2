CREATE OR ALTER PROCEDURE sp_AddMark
    @SubjectId INT,
    @StudentId INT,
    @Value INT,
    @Comment NVARCHAR(500) = NULL,
    @Weight INT = 1,
    @MarkId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @SubjectId IS NULL OR @StudentId IS NULL OR @Value IS NULL
        BEGIN
            RAISERROR('SubjectId, StudentId, and Value are required.', 16, 1);
            RETURN -1;
        END

        IF NOT EXISTS (SELECT 1 FROM subjects WHERE id = @SubjectId)
        BEGIN
            RAISERROR('Subject with ID %d does not exist.', 16, 1, @SubjectId);
            RETURN -1;
        END

        IF NOT EXISTS (SELECT 1 FROM students WHERE id = @StudentId)
        BEGIN
            RAISERROR('Student with ID %d does not exist.', 16, 1, @StudentId);
            RETURN -1;
        END

        IF @Value < 1 OR @Value > 6
        BEGIN
            RAISERROR('Mark value must be between 1 and 6.', 16, 1);
            RETURN -1;
        END

        IF @Weight < 1 OR @Weight > 10
        BEGIN
            RAISERROR('Weight must be between 1 and 10.', 16, 1);
            RETURN -1;
        END

        INSERT INTO marks (subjectId, studentId, value, comment, weight)
        VALUES (@SubjectId, @StudentId, @Value, @Comment, @Weight);

        SET @MarkId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @MarkId as MarkId, 'Mark added successfully' as Message;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
        RETURN -1;
    END CATCH
END;
GO