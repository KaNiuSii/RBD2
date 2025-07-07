
CREATE TABLE contracts (
    id NUMBER PRIMARY KEY,
    studentId NUMBER NOT NULL,
    parentId NUMBER NOT NULL,
    startDate DATE NOT NULL,
    endDate DATE,
    monthlyAmount NUMBER(10,2) NOT NULL
);

CREATE TABLE payments (
    id NUMBER PRIMARY KEY,
    contractId NUMBER NOT NULL,
    dueDate DATE NOT NULL,
    paidDate DATE,
    amount NUMBER(10,2) NOT NULL,
    status VARCHAR2(20) DEFAULT 'PENDING',
    CONSTRAINT fk_payments_contract FOREIGN KEY (contractId) REFERENCES contracts(id)
);

CREATE SEQUENCE contract_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE payment_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER contract_trigger
BEFORE INSERT ON contracts
FOR EACH ROW
BEGIN
    SELECT contract_seq.NEXTVAL INTO :NEW.id FROM dual;
END;
/

CREATE OR REPLACE TRIGGER payment_trigger
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    SELECT payment_seq.NEXTVAL INTO :NEW.id FROM dual;
END;
/

CREATE INDEX idx_contracts_student ON contracts(studentId);
CREATE INDEX idx_contracts_parent ON contracts(parentId);
CREATE INDEX idx_payments_contract ON payments(contractId);
CREATE INDEX idx_payments_status ON payments(status);