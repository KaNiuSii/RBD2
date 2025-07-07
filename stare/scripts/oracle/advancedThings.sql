-- Connect as contracts_admin user
CONNECT contracts_admin/secure_password;

-- Create a private database link to MSSQL (main server)
CREATE DATABASE LINK mssql_private_link
CONNECT TO "mssql_user" IDENTIFIED BY "mssql_password"
USING '(DESCRIPTION=
         (ADDRESS=(PROTOCOL=TCP)(HOST=mssql_server_host)(PORT=1521))
         (CONNECT_DATA=(SID=mssql_sid))
         (HS=OK)
        )';

-- Create a public database link to MSSQL (available to all users)
CREATE PUBLIC DATABASE LINK mssql_public_link
CONNECT TO "mssql_user" IDENTIFIED BY "mssql_password"
USING '(DESCRIPTION=
         (ADDRESS=(PROTOCOL=TCP)(HOST=mssql_server_host)(PORT=1521))
         (CONNECT_DATA=(SID=mssql_sid))
         (HS=OK)
        )';

-- Create a private database link to PostgreSQL
CREATE DATABASE LINK postgres_link
CONNECT TO "postgres_user" IDENTIFIED BY "postgres_password"
USING '(DESCRIPTION=
         (ADDRESS=(PROTOCOL=TCP)(HOST=postgres_server_host)(PORT=1521))
         (CONNECT_DATA=(SID=postgres_sid))
         (HS=OK)
        )';

-- Test the database links
SELECT 'MSSQL Private Link Test' AS test_name, COUNT(*) AS record_count
FROM students@mssql_private_link
WHERE ROWNUM <= 5;

SELECT 'MSSQL Public Link Test' AS test_name, COUNT(*) AS record_count
FROM students@mssql_public_link
WHERE ROWNUM <= 5;

SELECT 'PostgreSQL Link Test' AS test_name, COUNT(*) AS record_count
FROM remark@postgres_link
WHERE ROWNUM <= 5;

-- Create distributed view for student information
CREATE OR REPLACE VIEW vw_student_info AS
SELECT 
    s.id AS student_id,
    s.firstName AS first_name, 
    s.lastName AS last_name,
    s.birthday,
    g.value AS gender,
    gr.id AS group_id,
    t.firstName || ' ' || t.lastName AS home_teacher
FROM 
    students@mssql_private_link s
JOIN 
    genders@mssql_private_link g ON s.genderId = g.id
JOIN 
    groups@mssql_private_link gr ON s.groupId = gr.id
JOIN 
    teachers@mssql_private_link t ON gr.home_teacher_id = t.id;

-- Create distributed view for student financial status
CREATE OR REPLACE VIEW vw_student_financial_status AS
SELECT 
    s.id AS student_id,
    s.firstName || ' ' || s.lastName AS student_name,
    c.id AS contract_id,
    c.startDate AS contract_start,
    c.endDate AS contract_end,
    c.monthlyAmount AS monthly_fee,
    COUNT(p.id) AS total_payments,
    SUM(CASE WHEN p.status = 'PAID' THEN 1 ELSE 0 END) AS paid_payments,
    SUM(CASE WHEN p.status = 'PENDING' THEN 1 ELSE 0 END) AS pending_payments,
    SUM(CASE WHEN p.status = 'OVERDUE' THEN 1 ELSE 0 END) AS overdue_payments
FROM 
    students@mssql_private_link s
JOIN 
    contracts c ON s.id = c.studentId
LEFT JOIN 
    payments p ON c.id = p.contractId
GROUP BY 
    s.id, s.firstName, s.lastName, c.id, c.startDate, c.endDate, c.monthlyAmount;

-- Create distributed view for student remarks
CREATE OR REPLACE VIEW vw_student_remarks AS
SELECT 
    s.id AS student_id,
    s.firstName || ' ' || s.lastName AS student_name,
    t.firstName || ' ' || t.lastName AS teacher_name,
    r.value AS remark_text,
    r.severity,
    r.category,
    r.created_date
FROM 
    students@mssql_private_link s
JOIN 
    remark@postgres_link r ON s.id = r.studentId
JOIN 
    teachers@mssql_private_link t ON r.teacherId = t.id;

-- Create comprehensive student view
CREATE OR REPLACE VIEW vw_student_complete AS
SELECT 
    si.student_id,
    si.first_name,
    si.last_name,
    si.birthday,
    si.gender,
    si.group_id,
    si.home_teacher,
    fs.contract_id,
    fs.contract_start,
    fs.contract_end,
    fs.monthly_fee,
    fs.total_payments,
    fs.paid_payments,
    fs.pending_payments,
    fs.overdue_payments,
    COALESCE(sr.remark_count, 0) AS remark_count,
    COALESCE(sr.serious_remark_count, 0) AS serious_remark_count
FROM 
    vw_student_info si
LEFT JOIN 
    vw_student_financial_status fs ON si.student_id = fs.student_id
LEFT JOIN 
    (
        SELECT 
            student_id, 
            COUNT(*) AS remark_count,
            SUM(CASE WHEN severity IN ('SERIOUS', 'CRITICAL') THEN 1 ELSE 0 END) AS serious_remark_count
        FROM vw_student_remarks
        GROUP BY student_id
    ) sr ON si.student_id = sr.student_id;

-- Create INSTEAD OF trigger for vw_student_financial_status
CREATE OR REPLACE TRIGGER trg_student_financial_io
INSTEAD OF UPDATE ON vw_student_financial_status
FOR EACH ROW
DECLARE
    v_contract_exists NUMBER;
BEGIN
    -- Check if contract exists
    SELECT COUNT(*)
    INTO v_contract_exists
    FROM contracts
    WHERE id = :NEW.contract_id;
    
    IF v_contract_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Contract not found with ID: ' || :NEW.contract_id);
    END IF;
    
    -- Update the contract
    UPDATE contracts
    SET 
        startDate = :NEW.contract_start,
        endDate = :NEW.contract_end,
        monthlyAmount = :NEW.monthly_fee
    WHERE id = :NEW.contract_id;
    
    -- Log the update
    INSERT INTO contract_update_log (
        contract_id,
        update_date,
        old_start_date,
        new_start_date,
        old_end_date,
        new_end_date,
        old_monthly_amount,
        new_monthly_amount,
        updated_by
    ) VALUES (
        :NEW.contract_id,
        SYSDATE,
        :OLD.contract_start,
        :NEW.contract_start,
        :OLD.contract_end,
        :NEW.contract_end,
        :OLD.monthly_fee,
        :NEW.monthly_fee,
        USER
    );
END;
/

-- Create contract_update_log table if it doesn't exist
CREATE TABLE contract_update_log (
    log_id NUMBER PRIMARY KEY,
    contract_id NUMBER NOT NULL,
    update_date DATE NOT NULL,
    old_start_date DATE,
    new_start_date DATE,
    old_end_date DATE,
    new_end_date DATE,
    old_monthly_amount NUMBER(10,2),
    new_monthly_amount NUMBER(10,2),
    updated_by VARCHAR2(30)
);

CREATE SEQUENCE contract_update_log_seq START WITH 1 INCREMENT BY 1;

-- Create INSTEAD OF trigger for inserting new payment
CREATE OR REPLACE VIEW vw_contract_payments AS
SELECT 
    c.id AS contract_id,
    c.studentId AS student_id,
    p.id AS payment_id,
    p.dueDate AS due_date,
    p.paidDate AS paid_date,
    p.amount,
    p.status
FROM 
    contracts c
JOIN 
    payments p ON c.id = p.contractId;

CREATE OR REPLACE TRIGGER trg_contract_payments_io
INSTEAD OF INSERT ON vw_contract_payments
FOR EACH ROW
DECLARE
    v_contract_exists NUMBER;
    v_new_payment_id NUMBER;
BEGIN
    -- Check if contract exists
    SELECT COUNT(*)
    INTO v_contract_exists
    FROM contracts
    WHERE id = :NEW.contract_id;
    
    IF v_contract_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Contract not found with ID: ' || :NEW.contract_id);
    END IF;
    
    -- Get new payment ID
    SELECT payments_seq.NEXTVAL INTO v_new_payment_id FROM DUAL;
    
    -- Insert new payment
    INSERT INTO payments (
        id,
        contractId,
        dueDate,
        paidDate,
        amount,
        status
    ) VALUES (
        v_new_payment_id,
        :NEW.contract_id,
        :NEW.due_date,
        :NEW.paid_date,
        :NEW.amount,
        :NEW.status
    );
    
    -- Return new payment ID
    DBMS_OUTPUT.PUT_LINE('New payment created with ID: ' || v_new_payment_id);
END;
/

-- Create INSTEAD OF trigger for vw_student_complete
CREATE OR REPLACE TRIGGER trg_student_complete_io
INSTEAD OF UPDATE ON vw_student_complete
FOR EACH ROW
DECLARE
    v_contract_exists NUMBER;
BEGIN
    -- We can only update contract details from this view
    -- Check if contract exists
    SELECT COUNT(*)
    INTO v_contract_exists
    FROM contracts
    WHERE id = :NEW.contract_id;
    
    IF v_contract_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Contract not found with ID: ' || :NEW.contract_id);
    END IF;
    
    -- Update the contract
    UPDATE contracts
    SET 
        startDate = :NEW.contract_start,
        endDate = :NEW.contract_end,
        monthlyAmount = :NEW.monthly_fee
    WHERE id = :NEW.contract_id;
    
    -- Log the update
    INSERT INTO contract_update_log (
        log_id,
        contract_id,
        update_date,
        old_start_date,
        new_start_date,
        old_end_date,
        new_end_date,
        old_monthly_amount,
        new_monthly_amount,
        updated_by
    ) VALUES (
        contract_update_log_seq.NEXTVAL,
        :NEW.contract_id,
        SYSDATE,
        :OLD.contract_start,
        :NEW.contract_start,
        :OLD.contract_end,
        :NEW.contract_end,
        :OLD.monthly_fee,
        :NEW.monthly_fee,
        USER
    );
END;
/

-- Create procedure to synchronize student data across all systems
CREATE OR REPLACE PROCEDURE sp_synchronize_student_data(
    p_student_id IN NUMBER,
    p_result OUT VARCHAR2
)
AS
    v_student_exists NUMBER;
    v_student_name VARCHAR2(100);
    v_contract_exists NUMBER;
    v_remark_exists NUMBER;
    v_contract_id NUMBER;
    v_error_message VARCHAR2(4000);
BEGIN
    -- Initialize result
    p_result := 'SUCCESS';
    
    -- Check if student exists in MSSQL
    BEGIN
        SELECT COUNT(*) INTO v_student_exists
        FROM students@mssql_private_link
        WHERE id = p_student_id;
        
        IF v_student_exists = 0 THEN
            p_result := 'ERROR: Student not found in main database';
            RETURN;
        END IF;
        
        -- Get student name
        SELECT firstName || ' ' || lastName INTO v_student_name
        FROM students@mssql_private_link
        WHERE id = p_student_id;
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_result := 'ERROR connecting to MSSQL: ' || v_error_message;
            RETURN;
    END;
    
    -- Check if contract exists in Oracle
    SELECT COUNT(*) INTO v_contract_exists
    FROM contracts
    WHERE studentId = p_student_id;
    
    IF v_contract_exists = 0 THEN
        -- Create new contract
        BEGIN
            -- Get parent ID
            DECLARE
                v_parent_id NUMBER;
            BEGIN
                SELECT parentId INTO v_parent_id
                FROM parents_students@mssql_private_link
                WHERE studentId = p_student_id
                AND ROWNUM = 1;
                
                -- Insert new contract
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
                    p_student_id,
                    v_parent_id,
                    SYSDATE,
                    ADD_MONTHS(SYSDATE, 12),
                    350.00
                );
                
                -- Insert initial payment
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
                    SYSDATE,
                    NULL,
                    350.00,
                    'PENDING'
                );
                
                p_result := p_result || ' - Created new contract and payment';
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_message := SQLERRM;
                    p_result := p_result || ' - ERROR creating contract: ' || v_error_message;
            END;
        END;
    ELSE
        -- Update existing contract if needed
        BEGIN
            SELECT id INTO v_contract_id
            FROM contracts
            WHERE studentId = p_student_id;
            
            -- Ensure contract has valid end date
            UPDATE contracts
            SET endDate = ADD_MONTHS(SYSDATE, 12)
            WHERE id = v_contract_id
            AND (endDate IS NULL OR endDate < SYSDATE);
            
            p_result := p_result || ' - Updated existing contract';
        EXCEPTION
            WHEN OTHERS THEN
                v_error_message := SQLERRM;
                p_result := p_result || ' - ERROR updating contract: ' || v_error_message;
        END;
    END IF;
    
    -- Check for remarks in PostgreSQL
    BEGIN
        SELECT COUNT(*) INTO v_remark_exists
        FROM remark@postgres_link
        WHERE studentId = p_student_id;
        
        -- Add synchronization remark in PostgreSQL
        EXECUTE IMMEDIATE '
            BEGIN
                INSERT INTO remarks.remark@postgres_link (
                    studentId,
                    teacherId,
                    value,
                    severity,
                    category
                ) VALUES (
                    ' || p_student_id || ',
                    1,
                    ''Synchronized student data from Oracle - ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || ''',
                    ''INFO'',
                    ''GENERAL''
                );
            END;';
        
        p_result := p_result || ' - Added synchronization remark';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_result := p_result || ' - ERROR adding remark: ' || v_error_message;
    END;
    
    -- Log the synchronization
    INSERT INTO synchronization_log (
        student_id,
        sync_date,
        status,
        message
    ) VALUES (
        p_student_id,
        SYSDATE,
        CASE WHEN INSTR(p_result, 'ERROR') > 0 THEN 'ERROR' ELSE 'SUCCESS' END,
        p_result
    );
    
    -- Return final result
    p_result := 'Synchronization for student ' || v_student_name || ' (' || p_student_id || '): ' || p_result;
END;
/

-- Create synchronization log table
CREATE TABLE synchronization_log (
    log_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id NUMBER NOT NULL,
    sync_date DATE NOT NULL,
    status VARCHAR2(10) NOT NULL,
    message VARCHAR2(4000)
);

-- Create procedure to generate payment reports
CREATE OR REPLACE PROCEDURE sp_generate_payment_report(
    p_start_date IN DATE,
    p_end_date IN DATE,
    p_group_id IN NUMBER DEFAULT NULL,
    p_cursor OUT SYS_REFCURSOR
)
AS
BEGIN
    OPEN p_cursor FOR
    SELECT 
        s.id AS student_id,
        s.firstName || ' ' || s.lastName AS student_name,
        g.id AS group_id,
        y.value AS academic_year,
        c.id AS contract_id,
        c.monthlyAmount AS monthly_fee,
        COUNT(p.id) AS total_payments,
        SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) AS total_paid,
        SUM(CASE WHEN p.status = 'PENDING' THEN p.amount ELSE 0 END) AS total_pending,
        SUM(CASE WHEN p.status = 'OVERDUE' THEN p.amount ELSE 0 END) AS total_overdue,
        ROUND(SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) / 
              SUM(p.amount) * 100, 2) AS payment_percentage
    FROM 
        students@mssql_private_link s
    JOIN 
        groups@mssql_private_link g ON s.groupId = g.id
    JOIN 
        years@mssql_private_link y ON g.yearId = y.id
    JOIN 
        contracts c ON s.id = c.studentId
    JOIN 
        payments p ON c.id = p.contractId
    WHERE 
        p.dueDate BETWEEN p_start_date AND p_end_date
        AND (p_group_id IS NULL OR g.id = p_group_id)
    GROUP BY 
        s.id, s.firstName, s.lastName, g.id, y.value, c.id, c.monthlyAmount
    ORDER BY 
        g.id, s.lastName, s.firstName;
END;
/

-- Create procedure to process payment from all databases
CREATE OR REPLACE PROCEDURE sp_process_payment(
    p_student_id IN NUMBER,
    p_amount IN NUMBER,
    p_payment_date IN DATE DEFAULT SYSDATE,
    p_result OUT VARCHAR2
)
AS
    v_contract_id NUMBER;
    v_contract_exists NUMBER;
    v_payment_id NUMBER;
    v_student_name VARCHAR2(100);
    v_pending_amount NUMBER := 0;
    v_error_message VARCHAR2(4000);
BEGIN
    -- Initialize result
    p_result := 'SUCCESS';
    
    -- Check if student exists in MSSQL
    BEGIN
        SELECT COUNT(*) INTO v_contract_exists
        FROM students@mssql_private_link
        WHERE id = p_student_id;
        
        IF v_contract_exists = 0 THEN
            p_result := 'ERROR: Student not found in main database';
            RETURN;
        END IF;
        
        -- Get student name
        SELECT firstName || ' ' || lastName INTO v_student_name
        FROM students@mssql_private_link
        WHERE id = p_student_id;
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_result := 'ERROR connecting to MSSQL: ' || v_error_message;
            RETURN;
    END;
    
    -- Check if contract exists
    SELECT COUNT(*) INTO v_contract_exists
    FROM contracts
    WHERE studentId = p_student_id;
    
    IF v_contract_exists = 0 THEN
        p_result := 'ERROR: No contract found for student';
        RETURN;
    END IF;
    
    -- Get contract ID
    SELECT id INTO v_contract_id
    FROM contracts
    WHERE studentId = p_student_id;
    
    -- Calculate pending amount
    SELECT NVL(SUM(amount), 0) INTO v_pending_amount
    FROM payments
    WHERE contractId = v_contract_id
    AND status = 'PENDING';
    
    IF v_pending_amount = 0 THEN
        p_result := 'ERROR: No pending payments found';
        RETURN;
    END IF;
    
    -- Process payment for oldest pending payment
    BEGIN
        SELECT id INTO v_payment_id
        FROM payments
        WHERE contractId = v_contract_id
        AND status = 'PENDING'
        AND ROWNUM = 1
        ORDER BY dueDate;
        
        UPDATE payments
        SET paidDate = p_payment_date,
            status = 'PAID'
        WHERE id = v_payment_id;
        
        -- Add remark in PostgreSQL
        EXECUTE IMMEDIATE '
            BEGIN
                INSERT INTO remarks.remark@postgres_link (
                    studentId,
                    teacherId,
                    value,
                    severity,
                    category
                ) VALUES (
                    ' || p_student_id || ',
                    1,
                    ''Payment of ' || p_amount || ' processed on ' || TO_CHAR(p_payment_date, 'YYYY-MM-DD') || ''',
                    ''INFO'',
                    ''GENERAL''
                );
            END;';
        
        p_result := 'Payment processed successfully for student ' || v_student_name || ' (' || p_student_id || ')';
    EXCEPTION
        WHEN OTHERS THEN
            v_error_message := SQLERRM;
            p_result := 'ERROR processing payment: ' || v_error_message;
    END;
    
    -- Log the payment
    INSERT INTO payment_log (
        payment_id,
        student_id,
        amount,
        payment_date,
        status,
        message
    ) VALUES (
        v_payment_id,
        p_student_id,
        p_amount,
        p_payment_date,
        CASE WHEN INSTR(p_result, 'ERROR') > 0 THEN 'ERROR' ELSE 'SUCCESS' END,
        p_result
    );
END;
/

-- Create payment log table
CREATE TABLE payment_log (
    log_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_id NUMBER,
    student_id NUMBER NOT NULL,
    amount NUMBER(10,2) NOT NULL,
    payment_date DATE NOT NULL,
    status VARCHAR2(10) NOT NULL,
    message VARCHAR2(4000)
);

-- Test distributed views
SELECT * FROM vw_student_info
WHERE ROWNUM <= 5;

SELECT * FROM vw_student_financial_status
WHERE ROWNUM <= 5;

SELECT * FROM vw_student_remarks
WHERE ROWNUM <= 5;

SELECT * FROM vw_student_complete
WHERE ROWNUM <= 5;

-- Test INSTEAD OF triggers
-- Update a contract through the view
DECLARE
    v_student_id NUMBER := 1; -- Replace with actual student ID
    v_contract_id NUMBER;
BEGIN
    -- Get contract ID
    SELECT contract_id INTO v_contract_id
    FROM vw_student_financial_status
    WHERE student_id = v_student_id
    AND ROWNUM = 1;
    
    -- Update contract
    UPDATE vw_student_financial_status
    SET 
        monthly_fee = 400.00,
        contract_end = ADD_MONTHS(SYSDATE, 24)
    WHERE contract_id = v_contract_id;
    
    DBMS_OUTPUT.PUT_LINE('Contract updated successfully');
END;
/

-- Test adding a new payment through the view
DECLARE
    v_contract_id NUMBER := 1; -- Replace with actual contract ID
BEGIN
    -- Insert new payment
    INSERT INTO vw_contract_payments (
        contract_id,
        due_date,
        paid_date,
        amount,
        status
    ) VALUES (
        v_contract_id,
        SYSDATE,
        NULL,
        350.00,
        'PENDING'
    );
    
    DBMS_OUTPUT.PUT_LINE('Payment added successfully');
END;
/

-- Test synchronization procedure
DECLARE
    v_student_id NUMBER := 1; -- Replace with actual student ID
    v_result VARCHAR2(4000);
BEGIN
    sp_synchronize_student_data(v_student_id, v_result);
    DBMS_OUTPUT.PUT_LINE(v_result);
END;
/

-- Test payment report procedure
DECLARE
    v_cursor SYS_REFCURSOR;
    v_student_id NUMBER;
    v_student_name VARCHAR2(100);
    v_group_id NUMBER;
    v_academic_year NUMBER;
    v_contract_id NUMBER;
    v_monthly_fee NUMBER;
    v_total_payments NUMBER;
    v_total_paid NUMBER;
    v_total_pending NUMBER;
    v_total_overdue NUMBER;
    v_payment_percentage NUMBER;
BEGIN
    -- Generate report for current month
    sp_generate_payment_report(
        TRUNC(SYSDATE, 'MM'),
        LAST_DAY(SYSDATE),
        NULL,
        v_cursor
    );
    
    -- Display results
    DBMS_OUTPUT.PUT_LINE('Payment Report for ' || TO_CHAR(SYSDATE, 'Month YYYY'));
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Student ID | Student Name | Group | Monthly Fee | Paid | Pending | Payment %');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    
    LOOP
        FETCH v_cursor INTO 
            v_student_id, v_student_name, v_group_id, v_academic_year, 
            v_contract_id, v_monthly_fee, v_total_payments, 
            v_total_paid, v_total_pending, v_total_overdue, v_payment_percentage;
        
        EXIT WHEN v_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(
            v_student_id || ' | ' ||
            v_student_name || ' | ' ||
            v_group_id || ' | ' ||
            v_monthly_fee || ' | ' ||
            v_total_paid || ' | ' ||
            v_total_pending || ' | ' ||
            v_payment_percentage || '%'
        );
    END LOOP;
    
    CLOSE v_cursor;
END;
/

-- Test payment processing
DECLARE
    v_student_id NUMBER := 1; -- Replace with actual student ID
    v_result VARCHAR2(4000);
BEGIN
    sp_process_payment(v_student_id, 350.00, SYSDATE, v_result);
    DBMS_OUTPUT.PUT_LINE(v_result);
END;
/

-- Create package for contract management
CREATE OR REPLACE PACKAGE contract_mgmt AS
    -- Add a new contract
    PROCEDURE add_contract(
        p_student_id IN NUMBER,
        p_parent_id IN NUMBER,
        p_monthly_amount IN NUMBER,
        p_start_date IN DATE DEFAULT SYSDATE,
        p_end_date IN DATE DEFAULT NULL,
        p_contract_id OUT NUMBER
    );
    
    -- Process a payment
    PROCEDURE process_payment(
        p_student_id IN NUMBER,
        p_amount IN NUMBER,
        p_payment_date IN DATE DEFAULT SYSDATE,
        p_result OUT VARCHAR2
    );
    
    -- Generate payment schedule
    PROCEDURE generate_payment_schedule(
        p_contract_id IN NUMBER,
        p_months IN NUMBER DEFAULT 12
    );
    
    -- Synchronize student data
    PROCEDURE sync_student_data(
        p_student_id IN NUMBER,
        p_result OUT VARCHAR2
    );
    
    -- Get contract status
    FUNCTION get_contract_status(
        p_contract_id IN NUMBER
    ) RETURN VARCHAR2;
    
    -- Get payment report
    PROCEDURE get_payment_report(
        p_start_date IN DATE,
        p_end_date IN DATE,
        p_group_id IN NUMBER DEFAULT NULL,
        p_cursor OUT SYS_REFCURSOR
    );
END contract_mgmt;
/

-- Implement package body
CREATE OR REPLACE PACKAGE BODY contract_mgmt AS
    -- Add a new contract
    PROCEDURE add_contract(
        p_student_id IN NUMBER,
        p_parent_id IN NUMBER,
        p_monthly_amount IN NUMBER,
        p_start_date IN DATE DEFAULT SYSDATE,
        p_end_date IN DATE DEFAULT NULL,
        p_contract_id OUT NUMBER
    ) IS
        v_student_exists NUMBER;
        v_parent_exists NUMBER;
        v_actual_end_date DATE;
    BEGIN
        -- Validate student exists
        SELECT COUNT(*) INTO v_student_exists
        FROM students@mssql_private_link
        WHERE id = p_student_id;
        
        IF v_student_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Student not found with ID: ' || p_student_id);
        END IF;
        
        -- Validate parent exists
        SELECT COUNT(*) INTO v_parent_exists
        FROM parents@mssql_private_link
        WHERE id = p_parent_id;
        
        IF v_parent_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Parent not found with ID: ' || p_parent_id);
        END IF;
        
        -- Set end date if null
        v_actual_end_date := NVL(p_end_date, ADD_MONTHS(p_start_date, 12));
        
        -- Create contract
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
            v_actual_end_date,
            p_monthly_amount
        );
        
        -- Generate initial payment records
        generate_payment_schedule(p_contract_id, 12);
    END add_contract;
    
    -- Process a payment
    PROCEDURE process_payment(
        p_student_id IN NUMBER,
        p_amount IN NUMBER,
        p_payment_date IN DATE DEFAULT SYSDATE,
        p_result OUT VARCHAR2
    ) IS
    BEGIN
        sp_process_payment(p_student_id, p_amount, p_payment_date, p_result);
    END process_payment;
    
    -- Generate payment schedule
    PROCEDURE generate_payment_schedule(
        p_contract_id IN NUMBER,
        p_months IN NUMBER DEFAULT 12
    ) IS
        v_contract_exists NUMBER;
        v_monthly_amount NUMBER;
        v_start_date DATE;
    BEGIN
        -- Validate contract exists
        SELECT COUNT(*) INTO v_contract_exists
        FROM contracts
        WHERE id = p_contract_id;
        
        IF v_contract_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Contract not found with ID: ' || p_contract_id);
        END IF;
        
        -- Get contract details
        SELECT monthlyAmount, startDate
        INTO v_monthly_amount, v_start_date
        FROM contracts
        WHERE id = p_contract_id;
        
        -- Generate payment schedule
        FOR i IN 0..(p_months-1) LOOP
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
                ADD_MONTHS(v_start_date, i),
                NULL,
                v_monthly_amount,
                'PENDING'
            );
        END LOOP;
    END generate_payment_schedule;
    
    -- Synchronize student data
    PROCEDURE sync_student_data(
        p_student_id IN NUMBER,
        p_result OUT VARCHAR2
    ) IS
    BEGIN
        sp_synchronize_student_data(p_student_id, p_result);
    END sync_student_data;
    
    -- Get contract status
    FUNCTION get_contract_status(
        p_contract_id IN NUMBER
    ) RETURN VARCHAR2 IS
        v_contract_exists NUMBER;
        v_end_date DATE;
        v_pending_payments NUMBER;
        v_overdue_payments NUMBER;
        v_status VARCHAR2(20);
    BEGIN
        -- Validate contract exists
        SELECT COUNT(*) INTO v_contract_exists
        FROM contracts
        WHERE id = p_contract_id;
        
        IF v_contract_exists = 0 THEN
            RETURN 'NOT_FOUND';
        END IF;
        
        -- Get contract details
        SELECT endDate
        INTO v_end_date
        FROM contracts
        WHERE id = p_contract_id;
        
        -- Check if expired
        IF v_end_date < SYSDATE THEN
            RETURN 'EXPIRED';
        END IF;
        
        -- Count pending and overdue payments
        SELECT 
            COUNT(CASE WHEN status = 'PENDING' THEN 1 END),
            COUNT(CASE WHEN status = 'OVERDUE' THEN 1 END)
        INTO v_pending_payments, v_overdue_payments
        FROM payments
        WHERE contractId = p_contract_id;
        
        -- Determine status
        IF v_overdue_payments > 0 THEN
            v_status := 'OVERDUE';
        ELSIF v_pending_payments > 0 THEN
            v_status := 'ACTIVE';
        ELSE
            v_status := 'PAID_IN_FULL';
        END IF;
        
        RETURN v_status;
    END get_contract_status;
    
    -- Get payment report
    PROCEDURE get_payment_report(
        p_start_date IN DATE,
        p_end_date IN DATE,
        p_group_id IN NUMBER DEFAULT NULL,
        p_cursor OUT SYS_REFCURSOR
    ) IS
    BEGIN
        sp_generate_payment_report(p_start_date, p_end_date, p_group_id, p_cursor);
    END get_payment_report;
    
END contract_mgmt;
/

-- Test the contract management package
DECLARE
    v_contract_id NUMBER;
    v_result VARCHAR2(4000);
    v_cursor SYS_REFCURSOR;
    
    -- Variables for cursor
    v_student_id NUMBER;
    v_student_name VARCHAR2(100);
    v_group_id NUMBER;
    v_academic_year NUMBER;
    v_monthly_fee NUMBER;
    v_total_paid NUMBER;
    v_total_pending NUMBER;
    v_payment_percentage NUMBER;
BEGIN
    -- Create a new contract
    contract_mgmt.add_contract(
        p_student_id => 2,         -- Replace with actual student ID
        p_parent_id => 2,          -- Replace with actual parent ID
        p_monthly_amount => 450.00,
        p_start_date => SYSDATE,
        p_end_date => ADD_MONTHS(SYSDATE, 12),
        p_contract_id => v_contract_id
    );
    
    DBMS_OUTPUT.PUT_LINE('Contract created with ID: ' || v_contract_id);
    DBMS_OUTPUT.PUT_LINE('Contract status: ' || contract_mgmt.get_contract_status(v_contract_id));
    
    -- Process a payment
    contract_mgmt.process_payment(
        p_student_id => 2,         -- Replace with actual student ID
        p_amount => 450.00,
        p_payment_date => SYSDATE,
        p_result => v_result
    );
    
    DBMS_OUTPUT.PUT_LINE('Payment result: ' || v_result);
    
    -- Synchronize student data
    contract_mgmt.sync_student_data(
        p_student_id => 2,         -- Replace with actual student ID
        p_result => v_result
    );
    
    DBMS_OUTPUT.PUT_LINE('Sync result: ' || v_result);
    
    -- Get payment report
    contract_mgmt.get_payment_report(
        p_start_date => TRUNC(SYSDATE, 'MM'),
        p_end_date => LAST_DAY(SYSDATE),
        p_cursor => v_cursor
    );
    
    -- Display report results
    DBMS_OUTPUT.PUT_LINE('Payment Report for ' || TO_CHAR(SYSDATE, 'Month YYYY'));
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    
    LOOP
        FETCH v_cursor INTO 
            v_student_id, v_student_name, v_group_id, v_academic_year, 
            v_contract_id, v_monthly_fee, v_total_payments, 
            v_total_paid, v_total_pending, v_total_overdue, v_payment_percentage;
        
        EXIT WHEN v_cursor%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE(
            v_student_id || ' | ' ||
            v_student_name || ' | ' ||
            v_monthly_fee || ' | ' ||
            v_total_paid || ' | ' ||
            v_payment_percentage || '%'
        );
    END LOOP;
    
    CLOSE v_cursor;
END;
/