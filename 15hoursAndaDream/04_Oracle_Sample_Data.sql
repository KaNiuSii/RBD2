
CONNECT FINANCE_DB/Finance123;

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(1, 1, DATE '2024-01-01', DATE '2024-12-31', 500.00);

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(2, 2, DATE '2024-01-01', DATE '2024-12-31', 550.00);

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(3, 3, DATE '2024-01-01', DATE '2024-12-31', 500.00);

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(4, 4, DATE '2024-01-01', DATE '2024-12-31', 600.00);

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(5, 5, DATE '2024-01-01', DATE '2024-12-31', 525.00);

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(6, 6, DATE '2024-01-01', DATE '2024-12-31', 575.00);

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(7, 7, DATE '2024-01-01', DATE '2024-12-31', 500.00);

INSERT INTO contracts (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(8, 8, DATE '2024-01-01', DATE '2024-12-31', 650.00);

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(1, DATE '2024-01-01', DATE '2024-01-01', 500.00, 'PAID');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(1, DATE '2024-02-01', DATE '2024-02-01', 500.00, 'PAID');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(1, DATE '2024-03-01', DATE '2024-03-01', 500.00, 'PAID');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(1, DATE '2024-04-01', NULL, 500.00, 'PENDING');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(2, DATE '2024-01-01', DATE '2024-01-01', 550.00, 'PAID');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(2, DATE '2024-02-01', DATE '2024-02-03', 550.00, 'PAID');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(2, DATE '2024-03-01', NULL, 550.00, 'OVERDUE');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(3, DATE '2024-01-01', DATE '2024-01-01', 500.00, 'PAID');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(3, DATE '2024-02-01', DATE '2024-02-01', 500.00, 'PAID');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(4, DATE '2024-01-01', DATE '2024-01-01', 600.00, 'PAID');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(4, DATE '2024-02-01', NULL, 600.00, 'PENDING');

INSERT INTO payments (contractId, dueDate, paidDate, amount, status) VALUES 
(5, DATE '2024-01-01', DATE '2024-01-01', 525.00, 'PAID');

CONNECT REMOTE_DB1/Remote123;

INSERT INTO contracts_remote (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(9, 1, DATE '2024-01-01', DATE '2024-12-31', 500.00);

INSERT INTO contracts_remote (studentId, parentId, startDate, endDate, monthlyAmount) VALUES 
(10, 2, DATE '2024-01-01', DATE '2024-12-31', 550.00);

CONNECT REMOTE_DB2/Remote123;

INSERT INTO payment_summary (contractId, totalAmount, paymentCount, lastPaymentDate) VALUES 
(1, 1500.00, 3, DATE '2024-03-01');

INSERT INTO payment_summary (contractId, totalAmount, paymentCount, lastPaymentDate) VALUES 
(2, 1100.00, 2, DATE '2024-02-03');

INSERT INTO payment_summary (contractId, totalAmount, paymentCount, lastPaymentDate) VALUES 
(3, 1000.00, 2, DATE '2024-02-01');

INSERT INTO payment_summary (contractId, totalAmount, paymentCount, lastPaymentDate) VALUES 
(4, 600.00, 1, DATE '2024-01-01');

INSERT INTO payment_summary (contractId, totalAmount, paymentCount, lastPaymentDate) VALUES 
(5, 525.00, 1, DATE '2024-01-01');

COMMIT;

