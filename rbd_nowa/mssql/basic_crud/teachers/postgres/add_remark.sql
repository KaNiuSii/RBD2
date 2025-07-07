CREATE PROCEDURE dbo.pg_add_remark
    @studentId INT,
    @teacherId INT,
    @value NVARCHAR(MAX)
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
        INSERT INTO OPENQUERY(POSTGRES_REMARKS, 
            ''SELECT studentid, teacherid, value FROM remarks_main.remark'')
        VALUES (' + 
            CAST(@studentId AS NVARCHAR(20)) + ', ' +
            CAST(@teacherId AS NVARCHAR(20)) + ', ''' +
            REPLACE(@value, '''', '''''') + '''
        )
    ';

    EXEC (@sql);
END
