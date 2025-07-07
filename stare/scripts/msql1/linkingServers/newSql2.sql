-- Add second SQL Server linked server
EXEC sp_addlinkedserver 
    @server = 'SQL2',
    @srvproduct = 'SQL Server';
GO

-- Add login mapping for second SQL Server
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'SQL2',
    @useself = 'TRUE';  -- Use current Windows authentication
GO

-- Alternative: Use SQL Server authentication
/*
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'SQL2',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'sql_username',
    @rmtpassword = 'sql_password';
GO
*/

-- Configure server options for second SQL Server
EXEC sp_serveroption 'SQL2', 'collation compatible', 'true';
EXEC sp_serveroption 'SQL2', 'data access', 'true';
EXEC sp_serveroption 'SQL2', 'dist', 'true';
EXEC sp_serveroption 'SQL2', 'pub', 'true';
EXEC sp_serveroption 'SQL2', 'rpc', 'true';
EXEC sp_serveroption 'SQL2', 'rpc out', 'true';
EXEC sp_serveroption 'SQL2', 'sub', 'true';
EXEC sp_serveroption 'SQL2', 'connect timeout', '0';
EXEC sp_serveroption 'SQL2', 'collation name', NULL;
EXEC sp_serveroption 'SQL2', 'lazy schema validation', 'false';
EXEC sp_serveroption 'SQL2', 'query timeout', '0';
EXEC sp_serveroption 'SQL2', 'use remote collation', 'true';
EXEC sp_serveroption 'SQL2', 'remote proc transaction promotion', 'true';
GO

-- Test second SQL Server connection
SELECT * FROM SQL2.SchoolManagement_Replica.dbo.students WHERE id <= 5;
GO