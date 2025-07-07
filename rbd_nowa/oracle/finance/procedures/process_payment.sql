CREATE OR REPLACE PROCEDURE sp_ProcessPayment (
    p_payment_id   IN NUMBER,
    p_paid_amount  IN NUMBER,
    p_paid_date    IN DATE DEFAULT SYSDATE,
    p_result       OUT VARCHAR2
) AS
    v_exists       NUMBER;
    v_expected_amt NUMBER;
BEGIN
    -- Sprawdź, czy płatność istnieje i ma status PENDING
    SELECT COUNT(*), MAX(amount)
    INTO v_exists, v_expected_amt
    FROM payments
    WHERE id = p_payment_id
      AND status = 'PENDING';

    IF v_exists = 0 THEN
        p_result := 'ERROR: Payment not found or already processed';
        RETURN;
    END IF;

    -- Sprawdź, czy zapłacona kwota jest wystarczająca
    IF p_paid_amount < v_expected_amt THEN
        -- Płatność częściowa – zmniejszamy kwotę, ale nie zmieniamy statusu
        UPDATE payments
        SET amount = v_expected_amt - p_paid_amount
        WHERE id = p_payment_id;

        p_result := 'INFO: Partial payment accepted, remaining: ' || TO_CHAR(v_expected_amt - p_paid_amount);
    ELSE
        -- Pełna płatność – ustawiamy status na PAID
        UPDATE payments
        SET
            status   = 'PAID',
            paidDate = p_paid_date
        WHERE id = p_payment_id;

        p_result := 'SUCCESS: Payment fully processed';
    END IF;

    --COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result := 'ERROR: ' || SQLERRM;
END sp_ProcessPayment;
/



SET SERVEROUTPUT ON;

select * from payments where contractid = 61;

DECLARE
    v_result VARCHAR2(100);
BEGIN
    sp_ProcessPayment(
        p_payment_id   => 43,
        p_paid_amount  => 100, 
        p_paid_date    => SYSDATE,
        p_result       => v_result
    );

    DBMS_OUTPUT.PUT_LINE('Result: ' || v_result);
END;
/