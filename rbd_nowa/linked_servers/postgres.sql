
IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'POSTGRES_REMARKS')
    EXEC master.dbo.sp_dropserver @server=N'POSTGRES_REMARKS', @droplogins='droplogins';
GO

EXEC master.dbo.sp_addlinkedserver 
    @server = N'POSTGRES_REMARKS',
    @srvproduct = N'PostgreSQL',
    @provider = N'MSDASQL',
    @datasrc  = N'PostgreSQL30'; 
GO

EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = N'POSTGRES_REMARKS',
    @useself = N'False',
    @locallogin = NULL,
    @rmtuser = N'remarks_user',
    @rmtpassword = N'Remarks123';
GO

SELECT * FROM [POSTGRES_REMARKS].[remarks_system].[remarks_main].[remark]
SELECT * FROM [POSTGRES_REMARKS].[school].[remarks_main].[remark]