
-- ==========================================
-- Oracle Database Setup Script
-- School Management System - Finance Database
-- ==========================================

-- Create the Finance database (in Oracle this would be a separate schema)
-- Connect as system user first to create users and schemas

-- Create users for simulating distributed environment
CREATE USER FINANCE_DB IDENTIFIED BY Finance123
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;

CREATE USER REMOTE_DB1 IDENTIFIED BY Remote123
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;

CREATE USER REMOTE_DB2 IDENTIFIED BY Remote123
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP;

-- Grant necessary privileges
GRANT CONNECT, RESOURCE TO FINANCE_DB;
GRANT CONNECT, RESOURCE TO REMOTE_DB1;
GRANT CONNECT, RESOURCE TO REMOTE_DB2;

-- Grant additional privileges for distributed operations
GRANT CREATE DATABASE LINK TO FINANCE_DB;
GRANT CREATE SYNONYM TO FINANCE_DB;
GRANT CREATE VIEW TO FINANCE_DB;
GRANT CREATE MATERIALIZED VIEW TO FINANCE_DB;
GRANT CREATE SEQUENCE TO FINANCE_DB;
GRANT CREATE TRIGGER TO FINANCE_DB;
GRANT CREATE PROCEDURE TO FINANCE_DB;

-- Grant same privileges to remote schemas
GRANT CREATE DATABASE LINK TO REMOTE_DB1;
GRANT CREATE SYNONYM TO REMOTE_DB1;
GRANT CREATE VIEW TO REMOTE_DB1;
GRANT CREATE PROCEDURE TO REMOTE_DB1;

GRANT CREATE DATABASE LINK TO REMOTE_DB2;
GRANT CREATE SYNONYM TO REMOTE_DB2;
GRANT CREATE VIEW TO REMOTE_DB2;
GRANT CREATE PROCEDURE TO REMOTE_DB2;

-- Connect as FINANCE_DB user
CONNECT FINANCE_DB/Finance123;

-- Create tables following the schema
CREATE TABLE contracts (
    id NUMBER PRIMARY KEY,
    studentId NUMBER NOT NULL,
    parentId NUMBER NOT NULL,
    startDate DATE NOT NULL,
    endDate DATE,
    monthlyAmount NUMBER(10,2) NOT NULL
);

CREATE TABLE payments (
    id NUMBER PRIMARY KEY,
    contractId NUMBER NOT NULL,
    dueDate DATE NOT NULL,
    paidDate DATE,
    amount NUMBER(10,2) NOT NULL,
    status VARCHAR2(20) DEFAULT 'PENDING',
    CONSTRAINT fk_payments_contract FOREIGN KEY (contractId) REFERENCES contracts(id)
);

-- Create sequences for auto-incrementing IDs
CREATE SEQUENCE contract_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE payment_seq START WITH 1 INCREMENT BY 1;

-- Create triggers for auto-incrementing IDs
CREATE OR REPLACE TRIGGER contract_trigger
BEFORE INSERT ON contracts
FOR EACH ROW
BEGIN
    SELECT contract_seq.NEXTVAL INTO :NEW.id FROM dual;
END;
/

CREATE OR REPLACE TRIGGER payment_trigger
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    SELECT payment_seq.NEXTVAL INTO :NEW.id FROM dual;
END;
/

-- Create indexes for better performance
CREATE INDEX idx_contracts_student ON contracts(studentId);
CREATE INDEX idx_contracts_parent ON contracts(parentId);
CREATE INDEX idx_payments_contract ON payments(contractId);
CREATE INDEX idx_payments_status ON payments(status);

-- Simulate remote database schemas
CONNECT REMOTE_DB1/Remote123;

-- Create a copy of contracts table in remote schema for simulation
CREATE TABLE contracts_remote (
    id NUMBER PRIMARY KEY,
    studentId NUMBER NOT NULL,
    parentId NUMBER NOT NULL,
    startDate DATE NOT NULL,
    endDate DATE,
    monthlyAmount NUMBER(10,2) NOT NULL
);

CREATE SEQUENCE contract_remote_seq START WITH 1000 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER contract_remote_trigger
BEFORE INSERT ON contracts_remote
FOR EACH ROW
BEGIN
    SELECT contract_remote_seq.NEXTVAL INTO :NEW.id FROM dual;
END;
/

GRANT SELECT, INSERT, UPDATE, DELETE
    ON contracts_remote
    TO FINANCE_DB;

CONNECT REMOTE_DB2/Remote123;

-- Create a payments summary table in another remote schema
CREATE TABLE payment_summary (
    id NUMBER PRIMARY KEY,
    contractId NUMBER NOT NULL,
    totalAmount NUMBER(10,2) NOT NULL,
    paymentCount NUMBER NOT NULL,
    lastPaymentDate DATE
);

CREATE SEQUENCE payment_summary_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER payment_summary_trigger
BEFORE INSERT ON payment_summary
FOR EACH ROW
BEGIN
    SELECT payment_summary_seq.NEXTVAL INTO :NEW.id FROM dual;
END;
/

GRANT SELECT, INSERT, UPDATE, DELETE
    ON payment_summary
    TO FINANCE_DB;

CONNECT FINANCE_DB/Finance123;

-- Create synonyms to simulate database links
CREATE SYNONYM remote_contracts FOR REMOTE_DB1.contracts_remote;
CREATE SYNONYM remote_payment_summary FOR REMOTE_DB2.payment_summary;

-- Grant cross-schema access permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON contracts TO REMOTE_DB1;
GRANT SELECT, INSERT, UPDATE, DELETE ON payments TO REMOTE_DB1;
GRANT SELECT, INSERT, UPDATE, DELETE ON contracts TO REMOTE_DB2;
GRANT SELECT, INSERT, UPDATE, DELETE ON payments TO REMOTE_DB2;

PROMPT 'Oracle Finance Database schema created successfully!';
