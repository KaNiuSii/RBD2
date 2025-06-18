-- Create a read-only view that combines student data from MSSQL with contract data
CREATE OR REPLACE VIEW vw_student_contracts AS
SELECT 
    c.id AS contract_id,
    s.id AS student_id,
    s.firstName || ' ' || s.lastName AS student_name,
    p.id AS parent_id,
    p.firstName || ' ' || p.lastName AS parent_name,
    c.startDate,
    c.endDate,
    c.monthlyAmount,
    (SELECT COUNT(*) FROM payments WHERE contractId = c.id AND status = 'PAID') AS payments_made,
    (SELECT COUNT(*) FROM payments WHERE contractId = c.id AND status = 'PENDING') AS payments_pending,
    (SELECT COUNT(*) FROM payments WHERE contractId = c.id AND status = 'OVERDUE') AS payments_overdue
FROM 
    contracts c,
    students@mssql_link s,
    parents@mssql_link p
WHERE 
    c.studentId = s.id
    AND c.parentId = p.id;

-- Create an INSTEAD OF trigger for the view
CREATE OR REPLACE TRIGGER trg_student_contracts_update
INSTEAD OF UPDATE ON vw_student_contracts
FOR EACH ROW
BEGIN
    -- Only allow updates to contract dates and monthly amount
    UPDATE contracts
    SET startDate = :NEW.startDate,
        endDate = :NEW.endDate,
        monthlyAmount = :NEW.monthlyAmount
    WHERE id = :OLD.contract_id;
END;
/