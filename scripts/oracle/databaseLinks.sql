-- Connection data needs to be changed before use


-- Create a private database link to the main MSSQL server
-- Note: You need to have Oracle Database Gateway for ODBC configured
CREATE DATABASE LINK mssql_link
CONNECT TO "mssql_user" IDENTIFIED BY "mssql_password"
USING '(DESCRIPTION=
         (ADDRESS=(PROTOCOL=TCP)(HOST=mssql_server_host)(PORT=1521))
         (CONNECT_DATA=(SID=mssql_sid))
         (HS=OK)
        )';

-- Create a public database link that others can use
CREATE PUBLIC DATABASE LINK mssql_public_link
CONNECT TO "mssql_user" IDENTIFIED BY "mssql_password"
USING '(DESCRIPTION=
         (ADDRESS=(PROTOCOL=TCP)(HOST=mssql_server_host)(PORT=1521))
         (CONNECT_DATA=(SID=mssql_sid))
         (HS=OK)
        )';

-- Test the database link
SELECT * FROM DUAL@mssql_link;