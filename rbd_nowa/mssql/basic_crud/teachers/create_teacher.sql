CREATE OR ALTER PROCEDURE sp_CreateTeacher
    @FirstName NVARCHAR(100),
    @LastName NVARCHAR(100),
    @Birthday DATE = NULL,
    @PhoneNumber NVARCHAR(20) = NULL,
    @Email NVARCHAR(100) = NULL,
    @AdditionalInfo NVARCHAR(500) = NULL,
    @TeacherId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @FirstName IS NULL OR @LastName IS NULL
        BEGIN
            RAISERROR('FirstName and LastName are required.', 16, 1);
            RETURN -1;
        END

        IF @Email IS NOT NULL AND @Email NOT LIKE '%@%.%'
        BEGIN
            RAISERROR('Invalid email format.', 16, 1);
            RETURN -1;
        END

        IF @Email IS NOT NULL AND EXISTS (SELECT 1 FROM teachers WHERE email = @Email)
        BEGIN
            RAISERROR('Email already exists.', 16, 1);
            RETURN -1;
        END

        INSERT INTO teachers (firstName, lastName, birthday, phoneNumber, email, additionalInfo)
        VALUES (@FirstName, @LastName, @Birthday, @PhoneNumber, @Email, @AdditionalInfo);

        SET @TeacherId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @TeacherId as TeacherId, 'Teacher created successfully' as Message;

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