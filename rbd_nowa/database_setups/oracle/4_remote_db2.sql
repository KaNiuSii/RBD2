
CREATE TABLE payment_summary (
    id NUMBER PRIMARY KEY,
    contractId NUMBER NOT NULL,
    totalAmount NUMBER(10,2) NOT NULL,
    paymentCount NUMBER NOT NULL,
    lastPaymentDate DATE
);

CREATE SEQUENCE payment_summary_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER payment_summary_trigger
BEFORE INSERT ON payment_summary
FOR EACH ROW
BEGIN
    SELECT payment_summary_seq.NEXTVAL INTO :NEW.id FROM dual;
END;
/

GRANT SELECT, INSERT, UPDATE, DELETE
    ON payment_summary
    TO FINANCE_DB;