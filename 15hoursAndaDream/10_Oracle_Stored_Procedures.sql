
-- ==========================================
-- Oracle Stored Procedures and Distributed Operations Script
-- School Management System - Finance Database
-- ==========================================

-- Connect as FINANCE_DB user
CONNECT FINANCE_DB/Finance123;

-- ==========================================
-- SECTION 1: Oracle Stored Procedures
-- ==========================================

-- Procedure to get contract information
CREATE OR REPLACE PROCEDURE sp_GetContractInfo (
    p_student_id IN NUMBER,
    p_cursor OUT SYS_REFCURSOR
)
AS
BEGIN
    OPEN p_cursor FOR
    SELECT 
        c.id,
        c.studentId,
        c.parentId,
        c.startDate,
        c.endDate,
        c.monthlyAmount,
        COUNT(p.id) as totalPayments,
        SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) as totalPaid,
        SUM(CASE WHEN p.status = 'PENDING' THEN p.amount ELSE 0 END) as totalPending
    FROM contracts c
        LEFT JOIN payments p ON c.id = p.contractId
    WHERE c.studentId = p_student_id
    GROUP BY c.id, c.studentId, c.parentId, c.startDate, c.endDate, c.monthlyAmount;
END sp_GetContractInfo;
/

-- Procedure to create new contract with automatic payment schedule
CREATE OR REPLACE PROCEDURE sp_CreateContractWithPayments (
    p_student_id IN NUMBER,
    p_parent_id IN NUMBER,
    p_start_date IN DATE,
    p_end_date IN DATE,
    p_monthly_amount IN NUMBER,
    p_contract_id OUT NUMBER
)
AS
    v_payment_date DATE;
    v_current_date DATE;
BEGIN
    -- Insert new contract
    INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount)
    VALUES (p_student_id, p_parent_id, p_start_date, p_end_date, p_monthly_amount)
    RETURNING id INTO p_contract_id;

    -- Create payment schedule
    v_current_date := p_start_date;

    WHILE v_current_date <= p_end_date LOOP
        -- Create payment due on the first of each month
        v_payment_date := TRUNC(v_current_date, 'MM');

        INSERT INTO payments (contractId, dueDate, amount, status)
        VALUES (p_contract_id, v_payment_date, p_monthly_amount, 'PENDING');

        -- Move to next month
        v_current_date := ADD_MONTHS(v_current_date, 1);
    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Contract created with ID: ' || p_contract_id);
END sp_CreateContractWithPayments;
/

-- Procedure to process payment
CREATE OR REPLACE PROCEDURE sp_ProcessPayment (
    p_payment_id IN NUMBER,
    p_paid_date IN DATE DEFAULT SYSDATE,
    p_result OUT VARCHAR2
)
AS
    v_payment_exists NUMBER;
    v_current_status VARCHAR2(20);
BEGIN
    -- Check if payment exists
    SELECT COUNT(*), MAX(status)
    INTO v_payment_exists, v_current_status
    FROM payments
    WHERE id = p_payment_id;

    IF v_payment_exists = 0 THEN
        p_result := 'ERROR: Payment not found';
        RETURN;
    END IF;

    IF v_current_status = 'PAID' THEN
        p_result := 'WARNING: Payment already processed';
        RETURN;
    END IF;

    -- Update payment status
    UPDATE payments
    SET 
        status = 'PAID',
        paidDate = p_paid_date
    WHERE id = p_payment_id;

    COMMIT;
    p_result := 'SUCCESS: Payment processed successfully';

    DBMS_OUTPUT.PUT_LINE('Payment ' || p_payment_id || ' processed on ' || TO_CHAR(p_paid_date, 'DD-MON-YYYY'));

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result := 'ERROR: ' || SQLERRM;
END sp_ProcessPayment;
/

-- Function to calculate outstanding balance
CREATE OR REPLACE FUNCTION fn_CalculateOutstandingBalance (
    p_student_id IN NUMBER
) RETURN NUMBER
AS
    v_total_due NUMBER := 0;
    v_total_paid NUMBER := 0;
    v_outstanding NUMBER := 0;
BEGIN
    SELECT 
        SUM(c.monthlyAmount * MONTHS_BETWEEN(c.endDate, c.startDate)),
        NVL(SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END), 0)
    INTO v_total_due, v_total_paid
    FROM contracts c
        LEFT JOIN payments p ON c.id = p.contractId
    WHERE c.studentId = p_student_id;

    v_outstanding := NVL(v_total_due, 0) - NVL(v_total_paid, 0);

    RETURN v_outstanding;
END fn_CalculateOutstandingBalance;
/

-- ==========================================
-- SECTION 2: Simulated Distributed Views
-- ==========================================

-- Create view simulating distributed data access
CREATE OR REPLACE VIEW vw_DistributedFinanceData AS
SELECT 
    'MAIN' as source_schema,
    c.id as contract_id,
    c.studentId,
    c.parentId,
    c.monthlyAmount,
    p.status as payment_status,
    p.amount as payment_amount,
    p.paidDate
FROM contracts c
    LEFT JOIN payments p ON c.id = p.contractId
UNION ALL
SELECT 
    'REMOTE1' as source_schema,
    cr.id + 1000 as contract_id,
    cr.studentId,
    cr.parentId,
    cr.monthlyAmount,
    'PENDING' as payment_status,
    cr.monthlyAmount as payment_amount,
    NULL as paidDate
FROM REMOTE_DB1.contracts_remote cr;

-- ==========================================
-- SECTION 3: INSTEAD OF Triggers
-- ==========================================

-- Create INSTEAD OF trigger for the distributed view
CREATE OR REPLACE TRIGGER tr_DistributedFinanceData_Insert
INSTEAD OF INSERT ON vw_DistributedFinanceData
FOR EACH ROW
BEGIN
    -- Determine which schema to insert into based on business logic
    IF :NEW.studentId > 100 THEN
        -- Insert into remote schema
        INSERT INTO REMOTE_DB1.contracts_remote (studentId, parentId, startDate, endDate, monthlyAmount)
        VALUES (:NEW.studentId, :NEW.parentId, SYSDATE, ADD_MONTHS(SYSDATE, 12), :NEW.monthlyAmount);
    ELSE
        -- Insert into main schema
        INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount)
        VALUES (:NEW.studentId, :NEW.parentId, SYSDATE, ADD_MONTHS(SYSDATE, 12), :NEW.monthlyAmount);
    END IF;
END;
/

-- INSTEAD OF trigger for updates
CREATE OR REPLACE TRIGGER tr_DistributedFinanceData_Update
INSTEAD OF UPDATE ON vw_DistributedFinanceData
FOR EACH ROW
BEGIN
    IF :OLD.source_schema = 'MAIN' THEN
        -- Update main contracts table
        UPDATE contracts 
        SET 
            monthlyAmount = :NEW.monthlyAmount,
            parentId = :NEW.parentId
        WHERE id = :OLD.contract_id;

        -- Update payments if needed
        IF :NEW.payment_status != :OLD.payment_status THEN
            UPDATE payments 
            SET 
                status = :NEW.payment_status,
                paidDate = CASE WHEN :NEW.payment_status = 'PAID' THEN SYSDATE ELSE NULL END
            WHERE contractId = :OLD.contract_id;
        END IF;
    ELSE
        -- Update remote contracts table
        UPDATE REMOTE_DB1.contracts_remote 
        SET 
            monthlyAmount = :NEW.monthlyAmount,
            parentId = :NEW.parentId
        WHERE id = (:OLD.contract_id - 1000);
    END IF;
END;
/

-- ==========================================
-- SECTION 4: Cross-Schema Stored Procedures
-- ==========================================

-- Procedure to perform cross-schema operations
CREATE OR REPLACE PROCEDURE sp_CrossSchemaFinanceReport (
    p_student_id IN NUMBER DEFAULT NULL,
    p_cursor OUT SYS_REFCURSOR
)
AS
BEGIN
    IF p_student_id IS NOT NULL THEN
        OPEN p_cursor FOR
        SELECT 
            source_schema,
            contract_id,
            studentId,
            monthlyAmount,
            payment_status,
            payment_amount
        FROM vw_DistributedFinanceData
        WHERE studentId = p_student_id
        ORDER BY source_schema, contract_id;
    ELSE
        OPEN p_cursor FOR
        SELECT 
            source_schema,
            COUNT(*) as contract_count,
            SUM(monthlyAmount) as total_monthly_amount,
            SUM(CASE WHEN payment_status = 'PAID' THEN payment_amount ELSE 0 END) as total_paid
        FROM vw_DistributedFinanceData
        GROUP BY source_schema
        ORDER BY source_schema;
    END IF;
END sp_CrossSchemaFinanceReport;
/

-- Procedure to sync data between schemas
CREATE OR REPLACE PROCEDURE sp_SyncBetweenSchemas (
    p_operation IN VARCHAR2 -- 'SYNC_TO_REMOTE' or 'SYNC_FROM_REMOTE'
)
AS
    v_count NUMBER := 0;
BEGIN
    IF p_operation = 'SYNC_TO_REMOTE' THEN
        -- Sync main contracts to remote schema
        INSERT INTO REMOTE_DB1.contracts_remote (studentId, parentId, startDate, endDate, monthlyAmount)
        SELECT studentId, parentId, startDate, endDate, monthlyAmount
        FROM contracts c
        WHERE NOT EXISTS (
            SELECT 1 FROM REMOTE_DB1.contracts_remote cr 
            WHERE cr.studentId = c.studentId AND cr.parentId = c.parentId
        );

        v_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Synced ' || v_count || ' contracts to remote schema');

    ELSIF p_operation = 'SYNC_FROM_REMOTE' THEN
        -- Sync remote contracts to main schema
        INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount)
        SELECT studentId, parentId, startDate, endDate, monthlyAmount
        FROM REMOTE_DB1.contracts_remote cr
        WHERE NOT EXISTS (
            SELECT 1 FROM contracts c 
            WHERE c.studentId = cr.studentId AND c.parentId = cr.parentId
        );

        v_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Synced ' || v_count || ' contracts from remote schema');
    END IF;

    COMMIT;
END sp_SyncBetweenSchemas;
/

-- ==========================================
-- SECTION 5: Package for Distributed Operations
-- ==========================================

-- Create package specification
CREATE OR REPLACE PACKAGE pkg_DistributedFinance AS
    -- Public type definitions
    TYPE t_finance_record IS RECORD (
        contract_id NUMBER,
        student_id NUMBER,
        parent_id NUMBER,
        monthly_amount NUMBER,
        total_paid NUMBER,
        outstanding_balance NUMBER
    );

    TYPE t_finance_table IS TABLE OF t_finance_record;

    -- Public procedure and function declarations
    FUNCTION fn_GetStudentFinanceData(p_student_id NUMBER) RETURN t_finance_table PIPELINED;

    PROCEDURE sp_DistributedPaymentProcessing(
        p_student_id IN NUMBER,
        p_payment_amount IN NUMBER,
        p_payment_date IN DATE DEFAULT SYSDATE,
        p_result OUT VARCHAR2
    );

    PROCEDURE sp_GenerateFinanceReport(
        p_report_type IN VARCHAR2, -- 'SUMMARY', 'DETAILED', 'OVERDUE'
        p_cursor OUT SYS_REFCURSOR
    );

END pkg_DistributedFinance;
/

-- Create package body
CREATE OR REPLACE PACKAGE BODY pkg_DistributedFinance AS

    FUNCTION fn_GetStudentFinanceData(p_student_id NUMBER) RETURN t_finance_table PIPELINED AS
        v_record t_finance_record;
    BEGIN
        FOR rec IN (
            SELECT 
                c.id,
                c.studentId,
                c.parentId,
                c.monthlyAmount,
                NVL(SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END), 0) as total_paid
            FROM contracts c
                LEFT JOIN payments p ON c.id = p.contractId
            WHERE c.studentId = p_student_id
            GROUP BY c.id, c.studentId, c.parentId, c.monthlyAmount
        ) LOOP
            v_record.contract_id := rec.id;
            v_record.student_id := rec.studentId;
            v_record.parent_id := rec.parentId;
            v_record.monthly_amount := rec.monthlyAmount;
            v_record.total_paid := rec.total_paid;
            v_record.outstanding_balance := fn_CalculateOutstandingBalance(rec.studentId);

            PIPE ROW(v_record);
        END LOOP;

        RETURN;
    END fn_GetStudentFinanceData;

    PROCEDURE sp_DistributedPaymentProcessing(
        p_student_id IN NUMBER,
        p_payment_amount IN NUMBER,
        p_payment_date IN DATE DEFAULT SYSDATE,
        p_result OUT VARCHAR2
    ) AS
        v_contract_id NUMBER;
        v_payment_id NUMBER;
        v_temp_result VARCHAR2(200);
    BEGIN
        -- Find the contract for the student
        SELECT id INTO v_contract_id
        FROM contracts
        WHERE studentId = p_student_id
        AND ROWNUM = 1;

        -- Find pending payment
        SELECT id INTO v_payment_id
        FROM payments
        WHERE contractId = v_contract_id
        AND status = 'PENDING'
        AND amount = p_payment_amount
        AND ROWNUM = 1;

        -- Process the payment
        sp_ProcessPayment(v_payment_id, p_payment_date, v_temp_result);
        p_result := v_temp_result;

        -- Update summary in remote schema
        MERGE INTO REMOTE_DB2.payment_summary ps
        USING (
            SELECT 
                c.id as contractId,
                SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) as totalAmount,
                COUNT(CASE WHEN p.status = 'PAID' THEN 1 END) as paymentCount,
                MAX(p.paidDate) as lastPaymentDate
            FROM contracts c
                LEFT JOIN payments p ON c.id = p.contractId
            WHERE c.studentId = p_student_id
            GROUP BY c.id
        ) src ON (ps.contractId = src.contractId)
        WHEN MATCHED THEN
            UPDATE SET 
                totalAmount = src.totalAmount,
                paymentCount = src.paymentCount,
                lastPaymentDate = src.lastPaymentDate
        WHEN NOT MATCHED THEN
            INSERT (contractId, totalAmount, paymentCount, lastPaymentDate)
            VALUES (src.contractId, src.totalAmount, src.paymentCount, src.lastPaymentDate);

        COMMIT;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_result := 'ERROR: Contract or pending payment not found';
        WHEN OTHERS THEN
            ROLLBACK;
            p_result := 'ERROR: ' || SQLERRM;
    END sp_DistributedPaymentProcessing;

    PROCEDURE sp_GenerateFinanceReport(
        p_report_type IN VARCHAR2,
        p_cursor OUT SYS_REFCURSOR
    ) AS
    BEGIN
        IF p_report_type = 'SUMMARY' THEN
            OPEN p_cursor FOR
            SELECT 
                COUNT(DISTINCT c.id) as total_contracts,
                COUNT(DISTINCT c.studentId) as total_students,
                SUM(c.monthlyAmount) as total_monthly_revenue,
                SUM(CASE WHEN p.status = 'PAID' THEN p.amount ELSE 0 END) as total_collected,
                SUM(CASE WHEN p.status = 'PENDING' THEN p.amount ELSE 0 END) as total_pending
            FROM contracts c
                LEFT JOIN payments p ON c.id = p.contractId;

        ELSIF p_report_type = 'DETAILED' THEN
            OPEN p_cursor FOR
            SELECT * FROM vw_DistributedFinanceData
            ORDER BY source_schema, studentId;

        ELSIF p_report_type = 'OVERDUE' THEN
            OPEN p_cursor FOR
            SELECT 
                c.studentId,
                c.parentId,
                p.dueDate,
                p.amount,
                TRUNC(SYSDATE - p.dueDate) as days_overdue
            FROM contracts c
                INNER JOIN payments p ON c.id = p.contractId
            WHERE p.status = 'PENDING'
            AND p.dueDate < SYSDATE
            ORDER BY p.dueDate;
        END IF;
    END sp_GenerateFinanceReport;

END pkg_DistributedFinance;
/

-- ==========================================
-- SECTION 6: Test the Procedures
-- ==========================================

-- Test the procedures
DECLARE
    v_cursor SYS_REFCURSOR;
    v_result VARCHAR2(200);
    v_contract_id NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing Oracle distributed procedures...');

    -- Test contract creation
    pkg_DistributedFinance.sp_DistributedPaymentProcessing(1, 500, SYSDATE, v_result);
    DBMS_OUTPUT.PUT_LINE('Payment processing result: ' || v_result);

    -- Test finance report
    pkg_DistributedFinance.sp_GenerateFinanceReport('SUMMARY', v_cursor);
    DBMS_OUTPUT.PUT_LINE('Finance report generated successfully');

    DBMS_OUTPUT.PUT_LINE('Oracle distributed procedures testing completed!');
END;
/

PROMPT 'Oracle stored procedures and distributed operations completed successfully!';
