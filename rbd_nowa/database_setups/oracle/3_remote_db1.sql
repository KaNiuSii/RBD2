
CREATE TABLE contracts_remote (
    id NUMBER PRIMARY KEY,
    studentId NUMBER NOT NULL,
    parentId NUMBER NOT NULL,
    startDate DATE NOT NULL,
    endDate DATE,
    monthlyAmount NUMBER(10,2) NOT NULL
);

CREATE SEQUENCE contract_remote_seq START WITH 1000 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER contract_remote_trigger
BEFORE INSERT ON contracts_remote
FOR EACH ROW
BEGIN
    SELECT contract_remote_seq.NEXTVAL INTO :NEW.id FROM dual;
END;
/

GRANT SELECT, INSERT, UPDATE, DELETE
    ON contracts_remote
    TO FINANCE_DB;