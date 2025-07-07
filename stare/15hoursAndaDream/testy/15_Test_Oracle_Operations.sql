SET SERVEROUTPUT ON;

-- Test 1: Basic contract operations
DECLARE
    v_contract_id NUMBER;
    v_result VARCHAR2(200);
BEGIN
    -- Create new contract with payments
    sp_CreateContractWithPayments(
        p_student_id => 99,
        p_parent_id => 1,
        p_start_date => DATE '2024-01-01',
        p_end_date => DATE '2024-12-31',
        p_monthly_amount => 600.00,
        p_contract_id => v_contract_id
    );

    DBMS_OUTPUT.PUT_LINE('Created contract with ID: ' || v_contract_id);

    -- Test payment processing
    SELECT id INTO v_contract_id FROM payments WHERE contractId = v_contract_id AND ROWNUM = 1;

    sp_ProcessPayment(
        p_payment_id => v_contract_id,
        p_paid_date => SYSDATE,
        p_result => v_result
    );

    DBMS_OUTPUT.PUT_LINE('Payment processing result: ' || v_result);
END;
/

-- Test 2: Financial calculations
DECLARE
    v_balance NUMBER;
BEGIN
    FOR rec IN (SELECT DISTINCT studentId FROM contracts WHERE ROWNUM <= 5) LOOP
        v_balance := fn_CalculateOutstandingBalance(rec.studentId);
        DBMS_OUTPUT.PUT_LINE('Student ' || rec.studentId || ' outstanding balance: ' || v_balance);
    END LOOP;
END;
/

-- Test 3: Cross-schema operations
DECLARE
    v_cursor SYS_REFCURSOR;
    v_source VARCHAR2(50);
    v_contract_count NUMBER;
    v_total_amount NUMBER;
    v_total_paid NUMBER;
BEGIN
    sp_CrossSchemaFinanceReport(NULL, v_cursor);

    LOOP
        FETCH v_cursor INTO v_source, v_contract_count, v_total_amount, v_total_paid;
        EXIT WHEN v_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('Schema: ' || v_source || 
                           ', Contracts: ' || v_contract_count || 
                           ', Total Amount: ' || v_total_amount ||
                           ', Total Paid: ' || v_total_paid);
    END LOOP;

    CLOSE v_cursor;
END;
/

-- Test 4: Distributed view operations
SELECT source_schema, COUNT(*) as RecordCount
FROM vw_DistributedFinanceData
GROUP BY source_schema;

-- Test 5: Package operations
DECLARE
    v_result VARCHAR2(200);
    v_cursor SYS_REFCURSOR;
    v_total_contracts NUMBER;
    v_total_students NUMBER;
    v_total_revenue NUMBER;
    v_total_collected NUMBER;
    v_total_pending NUMBER;
BEGIN
    -- Test distributed payment processing
    pkg_DistributedFinance.sp_DistributedPaymentProcessing(
        p_student_id => 1,
        p_payment_amount => 500,
        p_payment_date => SYSDATE,
        p_result => v_result
    );

    DBMS_OUTPUT.PUT_LINE('Distributed payment result: ' || v_result);

    -- Generate finance report
    pkg_DistributedFinance.sp_GenerateFinanceReport('SUMMARY', v_cursor);

    FETCH v_cursor INTO v_total_contracts, v_total_students, v_total_revenue, v_total_collected, v_total_pending;

    DBMS_OUTPUT.PUT_LINE('=== FINANCE SUMMARY ===');
    DBMS_OUTPUT.PUT_LINE('Total Contracts: ' || v_total_contracts);
    DBMS_OUTPUT.PUT_LINE('Total Students: ' || v_total_students);
    DBMS_OUTPUT.PUT_LINE('Total Revenue: ' || v_total_revenue);
    DBMS_OUTPUT.PUT_LINE('Total Collected: ' || v_total_collected);
    DBMS_OUTPUT.PUT_LINE('Total Pending: ' || v_total_pending);

    CLOSE v_cursor;
END;
/

-- Test 6: Data synchronization
BEGIN
    sp_SyncBetweenSchemas('SYNC_TO_REMOTE');
    sp_SyncBetweenSchemas('SYNC_FROM_REMOTE');
END;
/

