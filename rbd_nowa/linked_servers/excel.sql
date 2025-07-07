IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'EXCEL_DATA')
    EXEC master.dbo.sp_dropserver @server=N'EXCEL_DATA', @droplogins='droplogins';
GO

EXEC master.dbo.sp_addlinkedserver 
    @server = N'EXCEL_DATA',
    @srvproduct = N'Excel',
    @provider = N'Microsoft.ACE.OLEDB.12.0',
    @datasrc = N'C:\excel_exports\SchoolData.xlsx',
    @provstr = N'Excel 12.0;HDR=YES;';
GO