EXEC sp_addlinkedserver 
    @server = 'POSTGRES_LINK',
    @srvproduct = 'PostgreSQL',
    @provider = 'MSDASQL',
    @datasrc = 'PostgreSQL30';  -- nazwa DSN z ODBC

-- logowanie
EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = 'POSTGRES_LINK',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'postgres',
    @rmtpassword = 'postgres';

SELECT *
FROM [POSTGRES_LINK].[school].[public].[attendance];

SELECT *
FROM OPENQUERY(POSTGRES_LINK,
               'SELECT * FROM "public"."attendance"');