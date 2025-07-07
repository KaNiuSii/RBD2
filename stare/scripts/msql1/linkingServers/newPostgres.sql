-- Add PostgreSQL linked server using ODBC
EXEC sp_addlinkedserver 
    @server = 'POSTGRES_LINK',
    @srvproduct = 'PostgreSQL',
    @provider = 'MSDASQL',
    @datasrc = 'PostgreSQL_DSN';  -- Replace with your ODBC DSN name
GO

-- Alternative using direct connection string
/*
EXEC sp_addlinkedserver 
    @server = 'POSTGRES_LINK',
    @srvproduct = 'PostgreSQL',
    @provider = 'MSDASQL',
    @provstr = 'DRIVER={PostgreSQL UNICODE};SERVER=your_postgres_server;PORT=5432;DATABASE=remarks_system;UID=remarks_admin;PWD=secure_password;';
GO
*/

-- Add login mapping for PostgreSQL
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'POSTGRES_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'remarks_admin',  -- PostgreSQL username
    @rmtpassword = 'secure_password';  -- PostgreSQL password
GO

-- Configure server options for PostgreSQL
EXEC sp_serveroption 'POSTGRES_LINK', 'collation compatible', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'data access', 'true';
EXEC sp_serveroption 'POSTGRES_LINK', 'dist', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'pub', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'rpc', 'true';
EXEC sp_serveroption 'POSTGRES_LINK', 'rpc out', 'true';
EXEC sp_serveroption 'POSTGRES_LINK', 'sub', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'connect timeout', '0';
EXEC sp_serveroption 'POSTGRES_LINK', 'collation name', NULL;
EXEC sp_serveroption 'POSTGRES_LINK', 'lazy schema validation', 'false';
EXEC sp_serveroption 'POSTGRES_LINK', 'query timeout', '0';
EXEC sp_serveroption 'POSTGRES_LINK', 'use remote collation', 'true';
EXEC sp_serveroption 'POSTGRES_LINK', 'remote proc transaction promotion', 'true';
GO

-- Test PostgreSQL connection
SELECT * FROM OPENQUERY(POSTGRES_LINK, 'SELECT * FROM remarks.remark LIMIT 5');
GO