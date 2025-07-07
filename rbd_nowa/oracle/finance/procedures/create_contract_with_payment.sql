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
    INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount)
    VALUES (p_student_id, p_parent_id, p_start_date, p_end_date, p_monthly_amount)
    RETURNING id INTO p_contract_id;

    v_current_date := p_start_date;

    WHILE v_current_date <= p_end_date LOOP
        v_payment_date := TRUNC(v_current_date, 'MM');

        INSERT INTO payments (contractId, dueDate, amount, status)
        VALUES (p_contract_id, v_payment_date, p_monthly_amount, 'PENDING');

        v_current_date := ADD_MONTHS(v_current_date, 1);
    END LOOP;

    --COMMIT;

    DBMS_OUTPUT.PUT_LINE('Contract created with ID: ' || p_contract_id);
END sp_CreateContractWithPayments;
/

SET SERVEROUTPUT ON;

DECLARE
    v_contract_id   NUMBER;
    v_student_id    NUMBER := 30;
    v_parent_id     NUMBER := 1;
    v_start_date    DATE := TO_DATE('2025-07-01', 'YYYY-MM-DD');
    v_end_date      DATE := TO_DATE('2025-12-31', 'YYYY-MM-DD');
    v_monthly_amt   NUMBER := 1000;
BEGIN
    sp_CreateContractWithPayments(
        p_student_id     => v_student_id,
        p_parent_id      => v_parent_id,
        p_start_date     => v_start_date,
        p_end_date       => v_end_date,
        p_monthly_amount => v_monthly_amt,
        p_contract_id    => v_contract_id
    );

    DBMS_OUTPUT.PUT_LINE('New contract ID: ' || v_contract_id);
END;
/

SELECT * FROM contracts WHERE id = 61;