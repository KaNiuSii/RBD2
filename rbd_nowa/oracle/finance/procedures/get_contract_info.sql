
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

SET SERVEROUTPUT ON;

DECLARE
    v_cursor SYS_REFCURSOR;
    v_id            contracts.id%TYPE;
    v_studentId     contracts.studentId%TYPE;
    v_parentId      contracts.parentId%TYPE;
    v_startDate     contracts.startDate%TYPE;
    v_endDate       contracts.endDate%TYPE;
    v_monthlyAmount contracts.monthlyAmount%TYPE;
    v_totalPayments NUMBER;
    v_totalPaid     NUMBER;
    v_totalPending  NUMBER;
BEGIN
    sp_GetContractInfo(p_student_id => 1, p_cursor => v_cursor);

    LOOP
        FETCH v_cursor INTO
            v_id, v_studentId, v_parentId, v_startDate, v_endDate,
            v_monthlyAmount, v_totalPayments, v_totalPaid, v_totalPending;

        EXIT WHEN v_cursor%NOTFOUND;

        -- Wypisanie wszystkich danych
        DBMS_OUTPUT.PUT_LINE('Contract ID     : ' || v_id);
        DBMS_OUTPUT.PUT_LINE('Student ID      : ' || v_studentId);
        DBMS_OUTPUT.PUT_LINE('Parent ID       : ' || v_parentId);
        DBMS_OUTPUT.PUT_LINE('Start Date      : ' || TO_CHAR(v_startDate, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('End Date        : ' || TO_CHAR(v_endDate, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Monthly Amount  : ' || v_monthlyAmount);
        DBMS_OUTPUT.PUT_LINE('Total Payments  : ' || v_totalPayments);
        DBMS_OUTPUT.PUT_LINE('Total Paid      : ' || v_totalPaid);
        DBMS_OUTPUT.PUT_LINE('Total Pending   : ' || v_totalPending);
        DBMS_OUTPUT.PUT_LINE('-------------------------------');
    END LOOP;

    CLOSE v_cursor;
END;
/
