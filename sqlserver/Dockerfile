# ./sqlserver/Dockerfile
FROM mcr.microsoft.com/mssql/server:2022-latest

USER root
# unixODBC + sterownik psqlODBC (≈1 min)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        unixodbc unixodbc-dev odbc-postgresql && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ▼ (opcjonalnie) skopiuj paczki Instant Client, jeśli
#   chcesz Linked Server do Oracle przez ODBC
# COPY instantclient/* /opt/oracle/

USER mssql
