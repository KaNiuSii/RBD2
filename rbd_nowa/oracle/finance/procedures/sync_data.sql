CREATE OR REPLACE PROCEDURE sp_SyncBetweenSchemas (
    p_operation IN VARCHAR2
)
AS
    v_count NUMBER := 0;
BEGIN
    IF p_operation = 'SYNC_TO_REMOTE' THEN
        -- Sync main contracts to remote schema
        INSERT INTO REMOTE_DB1.contracts_remote (studentId, parentId, startDate, endDate, monthlyAmount)
        SELECT studentId, parentId, startDate, endDate, monthlyAmount
        FROM contracts c
        WHERE NOT EXISTS (
            SELECT 1 FROM REMOTE_DB1.contracts_remote cr 
            WHERE cr.studentId = c.studentId AND cr.parentId = c.parentId
        );

        v_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Synced ' || v_count || ' contracts to remote schema');

    ELSIF p_operation = 'SYNC_FROM_REMOTE' THEN
        -- Sync remote contracts to main schema
        INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount)
        SELECT studentId, parentId, startDate, endDate, monthlyAmount
        FROM REMOTE_DB1.contracts_remote cr
        WHERE NOT EXISTS (
            SELECT 1 FROM contracts c 
            WHERE c.studentId = cr.studentId AND c.parentId = cr.parentId
        );

        v_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Synced ' || v_count || ' contracts from remote schema');
    END IF;

    COMMIT;
END sp_SyncBetweenSchemas;
/

BEGIN
    sp_SyncBetweenSchemas('SYNC_TO_REMOTE');
END;
/

BEGIN
    sp_SyncBetweenSchemas('SYNC_FROM_REMOTE');
END;
/

-- TEST

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount)
VALUES (999, 888, TO_DATE('2025-07-01', 'YYYY-MM-DD'), TO_DATE('2025-12-31', 'YYYY-MM-DD'), 1200);

COMMIT;

SELECT * FROM contracts
WHERE studentId = 999 AND parentId = 888;

SELECT * FROM REMOTE_DB1.contracts_remote
WHERE studentId = 999 AND parentId = 888;

BEGIN
    sp_SyncBetweenSchemas('SYNC_TO_REMOTE');
END;
/

SELECT * FROM REMOTE_DB1.contracts_remote
WHERE studentId = 999 AND parentId = 888;