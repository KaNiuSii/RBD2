-- Add a linked server to the second SQL Server instance
EXEC sp_addlinkedserver
    @server     = N'SQL2',
    @srvproduct = N'',               -- pusty ciąg!
    @provider   = N'MSOLEDBSQL',
    @datasrc    = N'sql2,1433';      -- albo IP kontenera

-- Configure security for the linked server
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'SQL2',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'sa',
    @rmtpassword = 'Str0ng!Passw0rd';

SELECT [id]
      ,[building]
      ,[room_number]
      ,[capacity]
      ,[equipment]
      ,[active]
  FROM [SQL2].[RBD].[dbo].[classrooms]
GO

