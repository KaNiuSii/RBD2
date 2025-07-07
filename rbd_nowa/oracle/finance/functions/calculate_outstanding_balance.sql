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

SELECT fn_CalculateOutstandingBalance(1) AS outstanding_balance FROM dual;