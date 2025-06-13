EXEC sp_addlinkedserver 
    @server = 'POSTGRES_LINK',
    @srvproduct = 'PostgreSQL',
    @provider = 'MSDASQL',
    @datasrc = '127.0.0.1';  -- nazwa DSN z ODBC

-- logowanie
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'POSTGRES_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'postgres',
    @rmtpassword = 'your_password';
