
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


COMMIT;