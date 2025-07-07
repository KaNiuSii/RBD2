-- Enable Ad Hoc Distributed Queries (if not already enabled)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- Create Excel linked server
EXEC sp_addlinkedserver 
    @server = 'EXCEL_LINK',
    @srvproduct = 'Excel',
    @provider = 'Microsoft.ACE.OLEDB.12.0',
    @datasrc = 'C:\Data\Analytics.xlsx',  -- Replace with your Excel file path
    @provstr = 'Excel 12.0;HDR=YES;IMEX=1;';
GO

-- No login mapping needed for Excel files
-- Configure server options for Excel
EXEC sp_serveroption 'EXCEL_LINK', 'collation compatible', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'data access', 'true';
EXEC sp_serveroption 'EXCEL_LINK', 'dist', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'pub', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'rpc', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'rpc out', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'sub', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'connect timeout', '0';
EXEC sp_serveroption 'EXCEL_LINK', 'collation name', NULL;
EXEC sp_serveroption 'EXCEL_LINK', 'lazy schema validation', 'false';
EXEC sp_serveroption 'EXCEL_LINK', 'query timeout', '0';
EXEC sp_serveroption 'EXCEL_LINK', 'use remote collation', 'true';
GO