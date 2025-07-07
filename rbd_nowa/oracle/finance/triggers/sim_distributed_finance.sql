CREATE OR REPLACE TRIGGER tr_DistributedFinanceData_Insert
INSTEAD OF INSERT ON vw_DistributedFinanceData
FOR EACH ROW
BEGIN
    IF :NEW.studentId > 100 THEN
        INSERT INTO REMOTE_DB1.contracts_remote (studentId, parentId, startDate, endDate, monthlyAmount)
        VALUES (:NEW.studentId, :NEW.parentId, SYSDATE, ADD_MONTHS(SYSDATE, 12), :NEW.monthlyAmount);
    ELSE
        INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount)
        VALUES (:NEW.studentId, :NEW.parentId, SYSDATE, ADD_MONTHS(SYSDATE, 12), :NEW.monthlyAmount);
    END IF;
END;
/