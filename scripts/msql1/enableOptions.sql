-- Enable advanced features needed for distributed operations
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Enable Ad Hoc Distributed Queries
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;

-- Enable Distributed Transaction Coordinator
EXEC sp_configure 'remote access', 1;
RECONFIGURE;

-- Enable CLR Integration (if needed)
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;