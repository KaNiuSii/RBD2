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