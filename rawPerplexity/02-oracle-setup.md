# Oracle Database Setup Script

## 1. User and Tablespace Creation

```sql
-- Connect as a user with administrative privileges (like SYSTEM)
CONNECT SYSTEM/your_password;

-- Create a dedicated tablespace for the contracts system
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
```

## 2. Table Creation for Contracts System

```sql
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
```

## 3. Create Database Links to MSSQL

```sql
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
```

## 4. Create Stored Procedures for Contract Management

```sql
-- Create a procedure to add a new contract
CREATE OR REPLACE PROCEDURE add_contract(
    p_student_id IN NUMBER,
    p_parent_id IN NUMBER,
    p_start_date IN DATE,
    p_end_date IN DATE,
    p_monthly_amount IN DECIMAL,
    p_contract_id OUT NUMBER
) AS
BEGIN
    -- Validate that student exists in MSSQL
    DECLARE
        v_student_exists NUMBER := 0;
    BEGIN
        SELECT COUNT(*) INTO v_student_exists 
        FROM students@mssql_link 
        WHERE id = p_student_id;
        
        IF v_student_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Student does not exist in the main database');
        END IF;
    END;
    
    -- Validate that parent exists in MSSQL
    DECLARE
        v_parent_exists NUMBER := 0;
    BEGIN
        SELECT COUNT(*) INTO v_parent_exists 
        FROM parents@mssql_link 
        WHERE id = p_parent_id;
        
        IF v_parent_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Parent does not exist in the main database');
        END IF;
    END;
    
    -- Insert the new contract
    SELECT contracts_seq.NEXTVAL INTO p_contract_id FROM DUAL;
    
    INSERT INTO contracts (
        id,
        studentId,
        parentId,
        startDate,
        endDate,
        monthlyAmount
    ) VALUES (
        p_contract_id,
        p_student_id,
        p_parent_id,
        p_start_date,
        p_end_date,
        p_monthly_amount
    );
    
    -- Generate initial payment records for the next 3 months
    FOR i IN 0..2 LOOP
        INSERT INTO payments (
            id,
            contractId,
            dueDate,
            paidDate,
            amount,
            status
        ) VALUES (
            payments_seq.NEXTVAL,
            p_contract_id,
            ADD_MONTHS(p_start_date, i),
            NULL,
            p_monthly_amount,
            'PENDING'
        );
    END LOOP;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- Create a procedure to record a payment
CREATE OR REPLACE PROCEDURE record_payment(
    p_payment_id IN NUMBER,
    p_paid_date IN DATE,
    p_amount IN DECIMAL
) AS
    v_status VARCHAR2(20);
    v_due_amount DECIMAL(10,2);
BEGIN
    -- Get the current payment record
    SELECT status, amount INTO v_status, v_due_amount
    FROM payments
    WHERE id = p_payment_id;
    
    -- Check if payment is already paid
    IF v_status = 'PAID' THEN
        RAISE_APPLICATION_ERROR(-20003, 'This payment is already marked as paid');
    END IF;
    
    -- Update the payment record
    IF p_amount >= v_due_amount THEN
        UPDATE payments
        SET paidDate = p_paid_date,
            amount = p_amount,
            status = 'PAID'
        WHERE id = p_payment_id;
    ELSE
        UPDATE payments
        SET paidDate = p_paid_date,
            amount = p_amount,
            status = 'PENDING'
        WHERE id = p_payment_id;
    END IF;
    
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20004, 'Payment record not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
```

## 5. Create Distributed Views

```sql
-- Create a read-only view that combines student data from MSSQL with contract data
CREATE OR REPLACE VIEW vw_student_contracts AS
SELECT 
    c.id AS contract_id,
    s.id AS student_id,
    s.firstName || ' ' || s.lastName AS student_name,
    p.id AS parent_id,
    p.firstName || ' ' || p.lastName AS parent_name,
    c.startDate,
    c.endDate,
    c.monthlyAmount,
    (SELECT COUNT(*) FROM payments WHERE contractId = c.id AND status = 'PAID') AS payments_made,
    (SELECT COUNT(*) FROM payments WHERE contractId = c.id AND status = 'PENDING') AS payments_pending,
    (SELECT COUNT(*) FROM payments WHERE contractId = c.id AND status = 'OVERDUE') AS payments_overdue
FROM 
    contracts c,
    students@mssql_link s,
    parents@mssql_link p
WHERE 
    c.studentId = s.id
    AND c.parentId = p.id;

-- Create an INSTEAD OF trigger for the view
CREATE OR REPLACE TRIGGER trg_student_contracts_update
INSTEAD OF UPDATE ON vw_student_contracts
FOR EACH ROW
BEGIN
    -- Only allow updates to contract dates and monthly amount
    UPDATE contracts
    SET startDate = :NEW.startDate,
        endDate = :NEW.endDate,
        monthlyAmount = :NEW.monthlyAmount
    WHERE id = :OLD.contract_id;
END;
/
```

## 6. Insert Sample Data

```sql
-- Create a procedure to generate sample contracts and payments
CREATE OR REPLACE PROCEDURE generate_sample_data AS
    v_contract_id NUMBER;
    v_start_date DATE;
    v_end_date DATE;
    v_monthly_amount DECIMAL(10,2);
    v_student_id NUMBER;
    v_parent_id NUMBER;
    v_student_parent_pairs SYS.DBMS_SQL.NUMBER_TABLE;
    v_count NUMBER := 0;
    
    -- Cursor to get student-parent pairs from MSSQL
    CURSOR c_student_parents IS
        SELECT ps.studentId, ps.parentId
        FROM parents_students@mssql_link ps;
    
BEGIN
    -- Get student-parent pairs
    FOR pair IN c_student_parents LOOP
        v_count := v_count + 1;
        IF v_count <= 50 THEN  -- Limit to 50 contracts for sample data
            v_student_id := pair.studentId;
            v_parent_id := pair.parentId;
            
            -- Generate random contract data
            v_start_date := ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -FLOOR(DBMS_RANDOM.VALUE(0, 12)));
            v_end_date := ADD_MONTHS(v_start_date, 12); -- 1-year contract
            v_monthly_amount := ROUND(DBMS_RANDOM.VALUE(100, 500), 2);
            
            -- Insert contract
            SELECT contracts_seq.NEXTVAL INTO v_contract_id FROM DUAL;
            
            INSERT INTO contracts (
                id,
                studentId,
                parentId,
                startDate,
                endDate,
                monthlyAmount
            ) VALUES (
                v_contract_id,
                v_student_id,
                v_parent_id,
                v_start_date,
                v_end_date,
                v_monthly_amount
            );
            
            -- Generate payment records
            FOR i IN 0..11 LOOP  -- 12 monthly payments
                INSERT INTO payments (
                    id,
                    contractId,
                    dueDate,
                    paidDate,
                    amount,
                    status
                ) VALUES (
                    payments_seq.NEXTVAL,
                    v_contract_id,
                    ADD_MONTHS(v_start_date, i),
                    CASE 
                        WHEN i <= 6 THEN ADD_MONTHS(v_start_date, i) + FLOOR(DBMS_RANDOM.VALUE(1, 5))  -- Paid for first 6 months
                        ELSE NULL  -- Not paid for remaining months
                    END,
                    v_monthly_amount,
                    CASE 
                        WHEN i <= 6 THEN 'PAID'  -- Paid for first 6 months
                        WHEN ADD_MONTHS(v_start_date, i) < SYSDATE THEN 'OVERDUE'  -- Overdue if past due date
                        ELSE 'PENDING'  -- Pending for future months
                    END
                );
            END LOOP;
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Sample data generated: ' || v_count || ' contracts');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error generating sample data: ' || SQLERRM);
END;
/

-- Execute the sample data generation
BEGIN
    generate_sample_data;
END;
/
```

## 7. Create Roles and Permissions

```sql
-- Create roles for different types of users
CREATE ROLE contracts_readonly;
CREATE ROLE contracts_operator;
CREATE ROLE contracts_admin;

-- Grant permissions to readonly role
GRANT SELECT ON contracts TO contracts_readonly;
GRANT SELECT ON payments TO contracts_readonly;
GRANT SELECT ON vw_student_contracts TO contracts_readonly;

-- Grant permissions to operator role
GRANT contracts_readonly TO contracts_operator;
GRANT INSERT, UPDATE ON payments TO contracts_operator;
GRANT EXECUTE ON record_payment TO contracts_operator;

-- Grant permissions to admin role
GRANT contracts_operator TO contracts_admin;
GRANT ALL ON contracts TO contracts_admin;
GRANT ALL ON payments TO contracts_admin;
GRANT EXECUTE ON add_contract TO contracts_admin;

-- Create test users for each role
CREATE USER contracts_viewer IDENTIFIED BY "viewer_password" 
DEFAULT TABLESPACE contracts_tbs
QUOTA 0 ON contracts_tbs;
GRANT CREATE SESSION TO contracts_viewer;
GRANT contracts_readonly TO contracts_viewer;

CREATE USER contracts_clerk IDENTIFIED BY "clerk_password"
DEFAULT TABLESPACE contracts_tbs
QUOTA 10M ON contracts_tbs;
GRANT CREATE SESSION TO contracts_clerk;
GRANT contracts_operator TO contracts_clerk;

-- Output status
SELECT 'Oracle Contracts Database Setup Complete!' FROM DUAL;
SELECT 'Contracts created: ' || COUNT(*) FROM contracts;
SELECT 'Payments created: ' || COUNT(*) FROM payments;
```

---

**Next Steps:**
1. Modify the connection details to match your Oracle server configuration
2. Run the script as a user with administrative privileges
3. Verify the database link connection to your MSSQL server
4. Verify the sample data generation was successful
5. Test the views and stored procedures
6. Proceed with the PostgreSQL setup script