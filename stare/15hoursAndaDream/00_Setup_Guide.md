
# Distributed Database System Setup Guide
## School Management System

This guide provides step-by-step instructions for setting up a distributed database system across MSSQL, Oracle, and PostgreSQL with Excel integration.

## Prerequisites

### Software Requirements
1. **Microsoft SQL Server** (2016 or later)
   - SQL Server Management Studio (SSMS)
   - SQL Server Agent (for replication)

2. **Oracle Database** (11g or later)
   - Oracle SQL Developer (optional)

3. **PostgreSQL** (12 or later)
   - pgAdmin (optional)

4. **Microsoft Office** or **Microsoft Access Database Engine**
   - For Excel integration

### Network Requirements
- All database servers should be accessible to each other
- Proper firewall configuration for database ports:
  - SQL Server: 1433
  - Oracle: 1521
  - PostgreSQL: 5432

## Setup Instructions

### Step 1: MSSQL Database Setup
Execute these scripts in order on your SQL Server instance:

```sql
-- Run in SQL Server Management Studio
-- 1. Create main database and schema
EXEC(N'SQLCMD -S YourServerName -i "01_MSSQL_Database_Setup.sql"')

-- 2. Insert sample data
EXEC(N'SQLCMD -S YourServerName -i "02_MSSQL_Sample_Data.sql"')
```

### Step 2: Oracle Database Setup
Execute these scripts using SQL*Plus or Oracle SQL Developer:

```sql
-- Run as SYSTEM user first
-- 1. Create database and users
@03_Oracle_Database_Setup.sql

-- 2. Insert sample data
@04_Oracle_Sample_Data.sql

-- 3. Create stored procedures
@10_Oracle_Stored_Procedures.sql
```

### Step 3: PostgreSQL Database Setup
Execute these scripts using psql or pgAdmin:

```sql
-- Run as superuser (postgres)
-- 1. Create database and schemas
\i 05_PostgreSQL_Database_Setup.sql

-- 2. Insert sample data
\i 06_PostgreSQL_Sample_Data.sql

-- 3. Create functions and procedures
\i 11_PostgreSQL_Functions.sql
```

### Step 4: Configure Distributed Operations
Execute these scripts on the main SQL Server:

```sql
-- 4. Configure linked servers
EXEC(N'SQLCMD -S YourServerName -i "07_MSSQL_Linked_Servers.sql"')

-- 5. Set up distributed queries
EXEC(N'SQLCMD -S YourServerName -i "08_Distributed_Queries.sql"')

-- 6. Configure distributed transactions
EXEC(N'SQLCMD -S YourServerName -i "09_Distributed_Transactions.sql"')
```

### Step 5: Set Up Replication
Execute on SQL Server for data replication:

```sql
-- 7. Configure replication
EXEC(N'SQLCMD -S YourServerName -i "12_MSSQL_Replication.sql"')
```

### Step 6: Configure Excel Integration
Execute on SQL Server for Excel data access:

```sql
-- 8. Set up Excel integration
EXEC(N'SQLCMD -S YourServerName -i "13_Excel_Integration.sql"')
```

## Configuration Notes

### MSSQL Configuration
1. **Enable Distributed Transactions:**
   ```sql
   EXEC sp_configure 'remote proc trans', 1;
   RECONFIGURE;
   ```

2. **Configure MS DTC:**
   - Open Component Services
   - Navigate to Distributed Transaction Coordinator > Local DTC
   - Right-click Properties > Security tab
   - Enable: Network DTC Access, Allow Remote Clients, Allow Inbound, Allow Outbound
   - Set Authentication to "No Authentication Required" (for testing)

3. **Linked Server Connection Strings:**
   - Update server names, ports, and credentials in script 07
   - Ensure ODBC drivers are installed for PostgreSQL

### Oracle Configuration
1. **Network Configuration:**
   - Update tnsnames.ora if needed
   - Ensure listener is running on port 1521

2. **User Permissions:**
   - Grant necessary privileges to FINANCE_DB user
   - Configure cross-schema access permissions

### PostgreSQL Configuration
1. **pg_hba.conf Configuration:**
   ```
   # Add this line for SQL Server connection
   host    remarksdb    remarks_user    <SQL_SERVER_IP>/32    md5
   ```

2. **postgresql.conf Settings:**
   ```
   listen_addresses = '*'
   port = 5432
   ```

## Testing the Setup

### 1. Test Basic Connectivity
```sql
-- Test Oracle connection from MSSQL
SELECT * FROM ORACLE_FINANCE.FINANCE_DB.CONTRACTS;

-- Test PostgreSQL connection from MSSQL
SELECT * FROM OPENQUERY(POSTGRES_REMARKS, 'SELECT COUNT(*) FROM remarks_main.remark');
```

### 2. Test Distributed Transactions
```sql
-- Execute distributed transaction example
EXEC sp_DistributedTransactionExample1 
    @StudentId = 1, 
    @ParentId = 1, 
    @MonthlyAmount = 500.00, 
    @RemarkText = 'Test distributed transaction';
```

### 3. Test Replication
```sql
-- Monitor replication status
EXEC sp_MonitorReplicationStatus;

-- Start snapshot agents
EXEC sp_StartSnapshotAgents;
```

### 4. Test Excel Integration
```sql
-- Test Excel data reading (update path as needed)
EXEC sp_ReadExcelFile 
    @FilePath = 'C:\Data\StudentGrades.xlsx', 
    @SheetName = 'Sheet1';
```

## Troubleshooting

### Common Issues

1. **Linked Server Connection Failed**
   - Check firewall settings
   - Verify credentials
   - Test network connectivity
   - Ensure proper ODBC drivers are installed

2. **Distributed Transaction Failed**
   - Verify MS DTC configuration on all servers
   - Check network DTC access permissions
   - Ensure SQL Server Agent is running

3. **Replication Not Working**
   - Check SQL Server Agent service
   - Verify snapshot agent jobs are created
   - Check distribution database configuration

4. **Excel Access Denied**
   - Install Microsoft Access Database Engine Redistributable
   - Enable Ad Hoc Distributed Queries
   - Check file permissions

### Monitoring Commands

```sql
-- Check linked servers
SELECT * FROM sys.servers WHERE is_linked = 1;

-- Monitor distributed transactions
SELECT * FROM vw_DistributedTransactionHistory;

-- Check replication status
SELECT * FROM distribution.dbo.MSrepl_commands;

-- View Excel import log
SELECT * FROM ExcelImportLog ORDER BY ImportDate DESC;
```

## Security Considerations

1. **Database Security:**
   - Use strong passwords for all database accounts
   - Limit permissions to minimum required
   - Enable encryption for sensitive data

2. **Network Security:**
   - Use VPN or private networks for cross-server communication
   - Configure firewalls to allow only necessary ports
   - Consider using SSL/TLS for database connections

3. **Linked Server Security:**
   - Use specific login mappings instead of generic access
   - Regularly review and audit linked server connections
   - Monitor cross-server query activity

## Performance Optimization

1. **Indexing:**
   - Create appropriate indexes on frequently joined columns
   - Monitor query execution plans for distributed queries

2. **Replication Tuning:**
   - Adjust batch sizes for better performance
   - Schedule snapshot agents during low-activity periods

3. **Distributed Query Optimization:**
   - Use OPENQUERY for complex remote queries
   - Minimize data transfer between servers
   - Consider caching frequently accessed remote data

## Maintenance Tasks

### Daily Tasks
- Monitor replication agent status
- Check distributed transaction logs
- Verify linked server connectivity

### Weekly Tasks
- Review performance metrics
- Check database growth and space usage
- Update statistics on replicated tables

### Monthly Tasks
- Review and clean up old transaction logs
- Update linked server credentials if needed
- Test disaster recovery procedures

## Support and Documentation

For additional help and documentation:
- SQL Server Documentation: docs.microsoft.com/sql
- Oracle Documentation: docs.oracle.com
- PostgreSQL Documentation: postgresql.org/docs
- Microsoft Access Database Engine: microsoft.com/download

Remember to adjust all server names, IP addresses, file paths, and credentials according to your specific environment before executing these scripts.
