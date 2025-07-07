
CREATE OR REPLACE PACKAGE BODY pkg_DistributedFinance AS

    FUNCTION fn_GetStudentFinanceData(p_student_id NUMBER)
    RETURN t_finance_table PIPELINED
    AS
    v_rec t_finance_record;
    BEGIN
    FOR c IN (
        SELECT  c.id,
                c.studentId,
                c.parentId,
                c.monthlyAmount,
                c.startDate,
                c.endDate,
                NVL(SUM(CASE WHEN p.status = 'PAID' THEN p.amount END),0)   AS total_paid
        FROM      contracts c
        LEFT JOIN payments  p ON p.contractId = c.id
        WHERE     c.studentId = p_student_id
        GROUP BY  c.id, c.studentId, c.parentId,
                    c.monthlyAmount, c.startDate, c.endDate
    ) LOOP
        v_rec.contract_id        := c.id;
        v_rec.student_id         := c.studentId;
        v_rec.parent_id          := c.parentId;
        v_rec.monthly_amount     := c.monthlyAmount;
        v_rec.total_paid         := c.total_paid;

        /* outstanding liczony „per kontrakt”  */
        v_rec.outstanding_balance :=
                ( c.monthlyAmount *
                    ROUND(MONTHS_BETWEEN(c.endDate, c.startDate)) )
                - c.total_paid;

        PIPE ROW(v_rec);
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
        SELECT id
        INTO v_contract_id
        FROM ( SELECT id
                FROM contracts
                WHERE studentId = p_student_id
                ORDER BY id DESC )
        WHERE ROWNUM = 1;

        -- Find pending payment
        SELECT id
            INTO v_payment_id
            FROM payments
        WHERE contractId = v_contract_id
            AND status     = 'PENDING'
            AND amount     = p_payment_amount
        ORDER BY dueDate           /* najbliższy termin */
        FETCH FIRST 1 ROWS ONLY;

        -- Process the payment
        sp_ProcessPayment( v_payment_id,
                     p_payment_amount,
                     p_payment_date,
                     v_temp_result );
        p_result := v_temp_result;

        -- Update summary in remote schema
        MERGE INTO REMOTE_DB2.payment_summary  ps
        USING (
                SELECT c.id                                  AS contractId,
                    NVL(SUM(p.amount),0)                  AS totalAmount,
                    COUNT(p.id)                           AS paymentCount,
                    MAX(p.paidDate)                       AS lastPaymentDate
                FROM contracts c
            LEFT JOIN payments  p ON p.contractId = c.id
                WHERE c.id = v_contract_id                  -- <-- tylko ten kontrakt
                GROUP BY c.id
        ) src
        ON (ps.contractId = src.contractId)
        WHEN MATCHED THEN UPDATE
                SET totalAmount     = src.totalAmount,
                    paymentCount    = src.paymentCount,
                    lastPaymentDate = src.lastPaymentDate
        WHEN NOT MATCHED THEN
                INSERT (contractId,totalAmount,paymentCount,lastPaymentDate)
                VALUES (src.contractId,src.totalAmount,src.paymentCount,src.lastPaymentDate);

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