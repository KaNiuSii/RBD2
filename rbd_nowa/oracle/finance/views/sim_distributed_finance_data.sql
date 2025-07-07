CREATE OR REPLACE VIEW vw_DistributedFinanceData AS
SELECT 
    'MAIN' as source_schema,
    c.id as contract_id,
    c.studentId,
    c.parentId,
    c.monthlyAmount,
    p.status as payment_status,
    p.amount as payment_amount,
    p.paidDate
FROM contracts c
    LEFT JOIN payments p ON c.id = p.contractId
UNION ALL
SELECT 
    'REMOTE1' as source_schema,
    cr.id + 1000 as contract_id,
    cr.studentId,
    cr.parentId,
    cr.monthlyAmount,
    'PENDING' as payment_status,
    cr.monthlyAmount as payment_amount,
    NULL as paidDate
FROM REMOTE_DB1.contracts_remote cr;

SELECT * FROM vw_DistributedFinanceData;