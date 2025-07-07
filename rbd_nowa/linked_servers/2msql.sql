
IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'MSSQL_REPLICA')
    EXEC master.dbo.sp_dropserver @server=N'MSSQL_REPLICA', @droplogins='droplogins';
GO

EXEC master.dbo.sp_addlinkedserver 
    @server = N'MSSQL_REPLICA',
    @srvproduct = N'',  
    @provider   = N'MSOLEDBSQL',
    @datasrc    = N'127.0.0.1,1434';      
GO

EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = N'MSSQL_REPLICA',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'sa',
    @rmtpassword = 'Str0ng!Passw0rd';
GO