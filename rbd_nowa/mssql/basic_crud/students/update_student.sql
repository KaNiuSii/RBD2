CREATE OR ALTER PROCEDURE sp_UpdateStudent
    @StudentId INT,
    @GroupId INT = NULL,
    @FirstName NVARCHAR(100) = NULL,
    @LastName NVARCHAR(100) = NULL,
    @Birthday DATE = NULL,
    @GenderId INT = NULL
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

        IF @GroupId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM groups WHERE id = @GroupId)
        BEGIN
            RAISERROR('Group with ID %d does not exist.', 16, 1, @GroupId);
            RETURN -1;
        END

        IF @GenderId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM genders WHERE id = @GenderId)
        BEGIN
            RAISERROR('Gender with ID %d does not exist.', 16, 1, @GenderId);
            RETURN -1;
        END

        UPDATE students 
        SET 
            groupId = ISNULL(@GroupId, groupId),
            firstName = ISNULL(@FirstName, firstName),
            lastName = ISNULL(@LastName, lastName),
            birthday = ISNULL(@Birthday, birthday),
            genderId = ISNULL(@GenderId, genderId)
        WHERE id = @StudentId;

        COMMIT TRANSACTION;

        SELECT 'Student updated successfully' as Message;

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