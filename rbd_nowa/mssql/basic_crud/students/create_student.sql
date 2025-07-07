
USE SchoolDB;
GO

CREATE OR ALTER PROCEDURE sp_CreateStudent
    @GroupId INT,
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Birthday DATE = NULL,
    @GenderId INT = NULL,
    @StudentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @GroupId IS NULL OR @FirstName IS NULL OR @LastName IS NULL
        BEGIN
            RAISERROR('GroupId, FirstName, and LastName are required fields.', 16, 1);
            RETURN -1;
        END

        -- Check if group exists
        IF NOT EXISTS (SELECT 1 FROM groups WHERE id = @GroupId)
        BEGIN
            RAISERROR('Group with ID %d does not exist.', 16, 1, @GroupId);
            RETURN -1;
        END

        IF @GenderId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM genders WHERE id = @GenderId)
        BEGIN
            RAISERROR('Gender with ID %d does not exist.', 16, 1, @GenderId);
            RETURN -1;
        END

        IF @Birthday IS NOT NULL AND (@Birthday > GETDATE() OR @Birthday < DATEADD(YEAR, -25, GETDATE()))
        BEGIN
            RAISERROR('Invalid birthday. Student must be between 0 and 25 years old.', 16, 1);
            RETURN -1;
        END

        INSERT INTO students (groupId, firstName, lastName, birthday, genderId)
        VALUES (@GroupId, @FirstName, @LastName, @Birthday, @GenderId);

        SET @StudentId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @StudentId as StudentId, 'Student created successfully' as Message;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -1;
    END CATCH
END;
GO