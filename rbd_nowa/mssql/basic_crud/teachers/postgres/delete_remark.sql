CREATE PROCEDURE dbo.pg_delete_remark
    @id INT
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
        DELETE FROM OPENQUERY(POSTGRES_REMARKS, 
            ''SELECT id FROM remarks_main.remark'')
        WHERE id = ' + CAST(@id AS NVARCHAR(20)) + '
    ';

    EXEC (@sql);
END