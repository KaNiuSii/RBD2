-- Add a linked server to Oracle
EXEC sp_addlinkedserver 
    @server = 'ORACLE_LINK', 
    @srvproduct = 'Oracle',
    @provider = 'OraOLEDB.Oracle', 
    @datasrc = '127.0.0.1:1521/XEPDB1';

-- Configure security for the linked server
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'ORACLE_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'app',
    @rmtpassword = 'app';

SELECT *
FROM OPENQUERY(ORACLE_LINK, 'SELECT * FROM APP.STUDENTS');

EXEC master.dbo.sp_enum_oledb_providers;

EXEC master.dbo.sp_MSset_oledb_prop 
     N'OraOLEDB.Oracle', N'AllowInProcess', 1;

EXEC master.dbo.sp_MSset_oledb_prop 
     N'OraOLEDB.Oracle', N'DynamicParameters', 1;

EXEC sp_helpserver;

SELECT * FROM OPENQUERY(ORACLE_LINK, 'SELECT 1 FROM DUAL');