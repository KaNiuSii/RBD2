-- Connect as a user with administrative privileges (like SYSTEM)
CONNECT SYSTEM/your_password;

-- Create a dedicated tablespace for the contracts system

-- Same as with the msql creation, I used create tablespace without any parameters
CREATE TABLESPACE contracts_tbs
DATAFILE 'contracts_data.dbf' SIZE 500M AUTOEXTEND ON NEXT 100M MAXSIZE 2G;

-- Create a dedicated user for the contracts system
CREATE USER contracts_admin IDENTIFIED BY "secure_password"
DEFAULT TABLESPACE contracts_tbs
QUOTA UNLIMITED ON contracts_tbs;

-- Grant necessary privileges to the user
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE TRIGGER TO contracts_admin;
GRANT CREATE DATABASE LINK TO contracts_admin;
GRANT CREATE PUBLIC DATABASE LINK TO contracts_admin;
GRANT EXECUTE ANY PROCEDURE TO contracts_admin;
GRANT SELECT ANY TABLE TO contracts_admin;
GRANT GLOBAL QUERY REWRITE TO contracts_admin;

-- Switch to the new user
CONNECT contracts_admin/secure_password;

-- Create Contracts table
CREATE TABLE contracts (
    id NUMBER PRIMARY KEY,
    studentId NUMBER NOT NULL,
    parentId NUMBER NOT NULL,
    startDate DATE NOT NULL,
    endDate DATE,
    monthlyAmount DECIMAL(10,2) NOT NULL
);

-- Create Payments table
CREATE TABLE payments (
    id NUMBER PRIMARY KEY,
    contractId NUMBER NOT NULL,
    dueDate DATE NOT NULL,
    paidDate DATE,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR2(20) CHECK (status IN ('PENDING', 'PAID', 'OVERDUE', 'CANCELLED')),
    CONSTRAINT fk_payments_contract FOREIGN KEY (contractId) REFERENCES contracts(id)
);

-- Create sequences for auto-incrementing IDs
CREATE SEQUENCE contracts_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE payments_seq START WITH 1 INCREMENT BY 1;

-- Create indexes for better performance
CREATE INDEX idx_contracts_student ON contracts(studentId);
CREATE INDEX idx_contracts_parent ON contracts(parentId);
CREATE INDEX idx_contracts_dates ON contracts(startDate, endDate);
CREATE INDEX idx_payments_contract ON payments(contractId);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_due ON payments(dueDate);