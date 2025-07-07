------------------------------------------------------------------
-- Konfiguracja dostawcy OLE DB dla sterowników ODBC (MSDASQL)
-- Krok ten jest często wymagany, aby połączenie działało stabilnie.
------------------------------------------------------------------
-- Włączenie opcji 'AllowInProcess', co jest kluczowe dla MSDASQL [1]
EXEC master.dbo.sp_MSset_oledb_prop 
     N'MSDASQL', N'AllowInProcess', 1;
GO

-- Włączenie dynamicznych parametrów [1]
EXEC master.dbo.sp_MSset_oledb_prop 
     N'MSDASQL', N'DynamicParameters', 1;
GO

------------------------------------------------------------------
-- Usuwanie istniejącego serwera, aby skrypt był powtarzalny
------------------------------------------------------------------
IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'MONGODB_DOCKER')
BEGIN
    EXEC master.dbo.sp_dropserver @server = N'MONGODB_DOCKER', @droplogins = 'droplogins';
END
GO

------------------------------------------------------------------
-- 1. Dodanie serwera połączonego (Linked Server) do MongoDB [1]
------------------------------------------------------------------
EXEC master.dbo.sp_addlinkedserver 
    @server = 'MONGODB_DOCKER',        -- Nazwa, pod którą serwer będzie widoczny w SSMS
    @srvproduct = 'MongoDB',          -- Dowolna nazwa opisowa
    @provider = 'MSDASQL',            -- Dostawca OLE DB dla ODBC
    @datasrc = 'MongoDockerRBD';      -- Nazwa Twojego System DSN
GO

------------------------------------------------------------------
-- 2. Konfiguracja poświadczeń (loginu) dla serwera połączonego [1]
------------------------------------------------------------------
EXEC master.dbo.sp_addlinkedsrvlogin 
    @rmtsrvname = 'MONGODB_DOCKER',
    @useself = 'FALSE',               -- Nie używaj poświadczeń SQL bieżącego użytkownika
    @locallogin = NULL,               -- Zastosuj dla wszystkich lokalnych loginów
    @rmtuser = 'root',                -- Użytkownik zdalny
    @rmtpassword = 'root';            -- Hasło zdalne
GO

------------------------------------------------------------------
-- 3. Polecenia diagnostyczne i testowe
------------------------------------------------------------------
-- Wyświetl listę dostępnych dostawców OLE DB [1]
EXEC master.dbo.sp_enum_oledb_providers;
GO

-- Wyświetl listę skonfigurowanych serwerów połączonych [1]
EXEC master.dbo.sp_helpserver;
GO

-- Prosty test połączenia - odpowiednik 'SELECT 1 FROM DUAL' z Oracle [1]
PRINT 'Uruchamianie prostego testu połączenia (SELECT 1)...';
SELECT * FROM OPENQUERY(MONGODB_DOCKER, 'SELECT 1');
GO

SELECT
    _id,
    class_code,
    subject_code,
    teacher_info_name,      -- Flattened from teacher_info.name
    teacher_info_email,     -- Flattened from teacher_info.email
    lesson_time,
    room,
    recurring_pattern_type  -- Flattened from recurring_pattern.type
FROM OPENQUERY(MONGODB_DOCKER, 
    'SELECT 
        _id,
        class_code,
        subject_code,
        teacher_info_name,
        teacher_info_email,
        lesson_time,
        room,
        recurring_pattern_type
    FROM rbd_mongo.schedules 
    WHERE class_code = ''CS101'' '
);
GO

EXEC master.dbo.sp_serveroption 
    @server = N'MONGODB_DOCKER', 
    @optname = N'rpc out', 
    @optvalue = N'true';
GO

EXECUTE('SET SESSION type_conversion_mode = ''mysql'';') AT MONGODB_DOCKER;
GO


EXECUTE ('FLUSH SAMPLE;') AT MONGODB_DOCKER;
GO

SELECT *
FROM OPENQUERY(MONGODB_DOCKER, 
    'SELECT 
        CAST(title AS CHAR(4000)) AS title,
        CAST(description AS CHAR(4000)) AS description
    FROM rbd_mongo.resources'
);


SELECT *
FROM OPENQUERY(MONGODB_DOCKER, 
    'SELECT title FROM rbd_mongo.resources LIMIT 1');



