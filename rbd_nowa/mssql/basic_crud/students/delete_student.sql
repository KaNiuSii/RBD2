CREATE OR ALTER PROCEDURE sp_DeleteStudent
    @StudentId INT,
    @ForceDelete BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM students WHERE id = @StudentId)
        BEGIN
            RAISERROR('Student with ID %d does not exist.', 16, 1, @StudentId);
            RETURN -1;
        END

        DECLARE @HasMarks INT = (SELECT COUNT(*) FROM marks WHERE studentId = @StudentId);
        DECLARE @HasAttendance INT = (SELECT COUNT(*) FROM attendance_student WHERE studentId = @StudentId);
        DECLARE @HasParents INT = (SELECT COUNT(*) FROM parents_students WHERE studentId = @StudentId);

        IF (@HasMarks > 0 OR @HasAttendance > 0) AND @ForceDelete = 0
        BEGIN
            RAISERROR('Cannot delete student. Student has related marks or attendance records. Use @ForceDelete = 1 to override.', 16, 1);
            RETURN -1;
        END

        IF @ForceDelete = 1
        BEGIN
            DELETE FROM marks WHERE studentId = @StudentId;
            DELETE FROM attendance_student WHERE studentId = @StudentId;
        END

        DELETE FROM parents_students WHERE studentId = @StudentId;

        DELETE FROM students WHERE id = @StudentId;

        COMMIT TRANSACTION;

        SELECT 'Student deleted successfully' as Message;

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
