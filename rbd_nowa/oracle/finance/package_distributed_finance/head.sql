
CREATE OR REPLACE PACKAGE pkg_DistributedFinance AS
    TYPE t_finance_record IS RECORD (
        contract_id NUMBER,
        student_id NUMBER,
        parent_id NUMBER,
        monthly_amount NUMBER,
        total_paid NUMBER,
        outstanding_balance NUMBER
    );

    TYPE t_finance_table IS TABLE OF t_finance_record;

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