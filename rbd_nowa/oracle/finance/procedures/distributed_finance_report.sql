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

SET SERVEROUTPUT ON;

DECLARE
    v_cursor SYS_REFCURSOR;
    v_source_schema     VARCHAR2(30);
    v_contract_id       NUMBER;
    v_student_id        NUMBER;
    v_monthly_amount    NUMBER;
    v_payment_status    VARCHAR2(20);
    v_payment_amount    NUMBER;
BEGIN
    sp_CrossSchemaFinanceReport(p_student_id => 1, p_cursor => v_cursor);

    LOOP
        FETCH v_cursor INTO 
            v_source_schema, 
            v_contract_id, 
            v_student_id, 
            v_monthly_amount, 
            v_payment_status, 
            v_payment_amount;

        EXIT WHEN v_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('[' || v_source_schema || '] Contract: ' || v_contract_id || 
                             ', Student: ' || v_student_id ||
                             ', Amount: ' || v_monthly_amount ||
                             ', Status: ' || v_payment_status ||
                             ', Paid: ' || v_payment_amount);
    END LOOP;

    CLOSE v_cursor;
END;
/
