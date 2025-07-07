
IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'ORACLE_FINANCE')
    EXEC master.dbo.sp_dropserver @server=N'ORACLE_FINANCE', @droplogins='droplogins';
GO

EXEC master.dbo.sp_addlinkedserver 
    @server = N'ORACLE_FINANCE',
    @srvproduct = N'Oracle',
    @provider = N'OraOLEDB.Oracle',
    @datasrc = N'127.0.0.1:1521/PD19C';
GO

EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = N'ORACLE_FINANCE',
    @useself = N'False',
    @locallogin = NULL,
    @rmtuser = N'FINANCE_DB',
    @rmtpassword = N'Finance123';
GO

SELECT * FROM ORACLE_FINANCE..FINANCE_DB.CONTRACTS