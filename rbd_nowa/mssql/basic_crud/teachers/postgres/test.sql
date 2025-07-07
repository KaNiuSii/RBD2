DECLARE @newId INT;
DECLARE @sql NVARCHAR(MAX);

EXEC dbo.pg_add_remark @studentId = 1, @teacherId = 2, @value = N'To jest testowy remark';

SET @sql = N'
SELECT TOP 1 id AS newId
FROM OPENQUERY(POSTGRES_REMARKS, 
    ''SELECT id FROM remarks_main.remark ORDER BY id DESC'')
';
CREATE TABLE #tmp_id(newId INT);
INSERT INTO #tmp_id
EXEC(@sql);

SELECT TOP 1 @newId = newId FROM #tmp_id;
DROP TABLE #tmp_id;

SET @sql = N'
SELECT *
FROM OPENQUERY(POSTGRES_REMARKS, 
    ''SELECT * FROM remarks_main.remark WHERE id = ' + CAST(@newId AS NVARCHAR(20)) + '''
)';
EXEC(@sql);

EXEC dbo.pg_delete_remark @id = @newId;

SET @sql = N'
SELECT *
FROM OPENQUERY(POSTGRES_REMARKS, 
    ''SELECT * FROM remarks_main.remark WHERE id = ' + CAST(@newId AS NVARCHAR(20)) + '''
)';
EXEC(@sql);
