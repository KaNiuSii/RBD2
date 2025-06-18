-- Enable postgres_fdw extension
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- For SQL Server connection, you would typically use tds_fdw or odbc_fdw
-- Since we're connecting to MSSQL, we'll use a different approach
-- Install tds_fdw extension if available, or use dblink for basic connectivity

-- Alternative: Create a foreign data wrapper for ODBC (if available)
-- CREATE EXTENSION IF NOT EXISTS odbc_fdw;

-- For demonstration, we'll create a simple connection using dblink
CREATE EXTENSION IF NOT EXISTS dblink;

-- Create a connection function to MSSQL
CREATE OR REPLACE FUNCTION get_mssql_connection() 
RETURNS TEXT AS $$
BEGIN
    -- Replace with your actual MSSQL connection string
    RETURN 'host=mssql_server_ip port=1433 dbname=SchoolManagement user=mssql_user password=mssql_password';
END;
$$ LANGUAGE plpgsql;