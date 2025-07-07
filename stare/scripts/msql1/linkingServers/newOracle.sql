-- Connect to the main MSSQL server
USE master;
GO

-- Add Oracle linked server
EXEC sp_addlinkedserver 
    @server = 'ORACLE_LINK',
    @srvproduct = 'Oracle',
    @provider = 'OraOLEDB.Oracle',
    @datasrc = 'your_oracle_tnsname';  -- Replace with your Oracle TNS name or connection string
GO

-- Add login mapping for Oracle
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'ORACLE_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'contracts_admin',  -- Oracle username
    @rmtpassword = 'secure_password';  -- Oracle password
GO

-- Configure server options for Oracle
EXEC sp_serveroption 'ORACLE_LINK', 'collation compatible', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'data access', 'true';
EXEC sp_serveroption 'ORACLE_LINK', 'dist', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'pub', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'rpc', 'true';
EXEC sp_serveroption 'ORACLE_LINK', 'rpc out', 'true';
EXEC sp_serveroption 'ORACLE_LINK', 'sub', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'connect timeout', '0';
EXEC sp_serveroption 'ORACLE_LINK', 'collation name', NULL;
EXEC sp_serveroption 'ORACLE_LINK', 'lazy schema validation', 'false';
EXEC sp_serveroption 'ORACLE_LINK', 'query timeout', '0';
EXEC sp_serveroption 'ORACLE_LINK', 'use remote collation', 'true';
EXEC sp_serveroption 'ORACLE_LINK', 'remote proc transaction promotion', 'true';
GO

-- Test Oracle connection
SELECT * FROM ORACLE_LINK.contracts_admin.contracts WHERE ROWNUM <= 5;
GO