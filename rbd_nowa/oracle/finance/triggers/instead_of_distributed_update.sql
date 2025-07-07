--Ten trigger jest przypięty do widoku vw_DistributedFinanceData, a jego zadaniem jest 
--symulacja aktualizacji danych w systemie rozproszonym (danych pochodzących z różnych schematów lub "baz").

CREATE OR REPLACE TRIGGER tr_DistributedFinanceData_Update
INSTEAD OF UPDATE ON vw_DistributedFinanceData
FOR EACH ROW
BEGIN
    IF :OLD.source_schema = 'MAIN' THEN
        UPDATE contracts 
        SET 
            monthlyAmount = :NEW.monthlyAmount,
            parentId = :NEW.parentId
        WHERE id = :OLD.contract_id;

        IF :NEW.payment_status != :OLD.payment_status THEN
            UPDATE payments 
            SET 
                status = :NEW.payment_status,
                paidDate = CASE WHEN :NEW.payment_status = 'PAID' THEN SYSDATE ELSE NULL END
            WHERE contractId = :OLD.contract_id;
        END IF;
    ELSE
        UPDATE REMOTE_DB1.contracts_remote 
        SET 
            monthlyAmount = :NEW.monthlyAmount,
            parentId = :NEW.parentId
        WHERE id = (:OLD.contract_id - 1000);
    END IF;
END;
/