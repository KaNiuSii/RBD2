SET SERVEROUTPUT ON;

DECLARE
    v_contract_id   NUMBER;
    v_payment_id    NUMBER;
    v_result        VARCHAR2(200);
    v_cursor        SYS_REFCURSOR;

    -- Dane testowe
    v_student_id    NUMBER := 999;
    v_parent_id     NUMBER := 888;
    v_start_date    DATE := TO_DATE('2025-05-07', 'YYYY-MM-DD');
    v_end_date      DATE := TO_DATE('2025-09-04', 'YYYY-MM-DD');
    v_monthly_amount NUMBER := 1000;

    -- Zmienne do odczytu z kursora
    v_total_contracts     NUMBER;
    v_total_students      NUMBER;
    v_total_revenue       NUMBER;
    v_total_collected     NUMBER;
    v_total_pending       NUMBER;
BEGIN
    -- 1. Wstaw kontrakt i płatności
    sp_CreateContractWithPayments(
        p_student_id     => v_student_id,
        p_parent_id      => v_parent_id,
        p_start_date     => v_start_date,
        p_end_date       => v_end_date,
        p_monthly_amount => v_monthly_amount,
        p_contract_id    => v_contract_id
    );

    DBMS_OUTPUT.PUT_LINE('Utworzono kontrakt ID: ' || v_contract_id);

    -- 2. Przetwarzanie płatności
    pkg_DistributedFinance.sp_DistributedPaymentProcessing(
        p_student_id     => v_student_id,
        p_payment_amount => v_monthly_amount,
        p_result         => v_result
    );
    DBMS_OUTPUT.PUT_LINE('Przetwarzanie płatności: ' || v_result);

    -- 3. Wywołanie funkcji zwracającej dane finansowe studenta
    DBMS_OUTPUT.PUT_LINE('Dane finansowe studenta:');
    FOR rec IN (
        SELECT * FROM TABLE(pkg_DistributedFinance.fn_GetStudentFinanceData(v_student_id))
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  Kontrakt: ' || rec.contract_id || 
                             ', Zapłacono: ' || rec.total_paid || 
                             ', Do zapłaty: ' || rec.outstanding_balance);
    END LOOP;

    -- 4. Wygenerowanie raportu finansowego (summary)
    pkg_DistributedFinance.sp_GenerateFinanceReport('SUMMARY', v_cursor);

    FETCH v_cursor INTO 
        v_total_contracts, 
        v_total_students, 
        v_total_revenue, 
        v_total_collected, 
        v_total_pending;

    CLOSE v_cursor;

    DBMS_OUTPUT.PUT_LINE('--- PODSUMOWANIE ---');
    DBMS_OUTPUT.PUT_LINE('  Kontraktów: ' || v_total_contracts);
    DBMS_OUTPUT.PUT_LINE('  Studentów : ' || v_total_students);
    DBMS_OUTPUT.PUT_LINE('  Miesięczny przychód: ' || v_total_revenue);
    DBMS_OUTPUT.PUT_LINE('  Zapłacone: ' || v_total_collected);
    DBMS_OUTPUT.PUT_LINE('  Oczekujące: ' || v_total_pending);

    -- 5. Weryfikacja wpisu w remote_payment_summary
    DBMS_OUTPUT.PUT_LINE('--- REMOTE PAYMENT SUMMARY ---');
    FOR rec IN (
        SELECT * FROM REMOTE_DB2.payment_summary WHERE contractId = v_contract_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  Suma: ' || rec.totalAmount || 
                             ', Płatności: ' || rec.paymentCount || 
                             ', Ostatnia: ' || TO_CHAR(rec.lastPaymentDate, 'YYYY-MM-DD'));
    END LOOP;

    -- 6. sprzątanie po teście:
    DELETE FROM payments WHERE contractId = v_contract_id;
    DELETE FROM contracts WHERE id = v_contract_id;
    DELETE FROM REMOTE_DB2.payment_summary WHERE contractId = v_contract_id;
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('BŁĄD TESTU: ' || SQLERRM);
END;
/
