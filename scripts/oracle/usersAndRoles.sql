-- Create roles for different types of users
CREATE ROLE contracts_readonly;
CREATE ROLE contracts_operator;
CREATE ROLE contracts_admin;

-- Grant permissions to readonly role
GRANT SELECT ON contracts TO contracts_readonly;
GRANT SELECT ON payments TO contracts_readonly;
GRANT SELECT ON vw_student_contracts TO contracts_readonly;

-- Grant permissions to operator role
GRANT contracts_readonly TO contracts_operator;
GRANT INSERT, UPDATE ON payments TO contracts_operator;
GRANT EXECUTE ON record_payment TO contracts_operator;

-- Grant permissions to admin role
GRANT contracts_operator TO contracts_admin;
GRANT ALL ON contracts TO contracts_admin;
GRANT ALL ON payments TO contracts_admin;
GRANT EXECUTE ON add_contract TO contracts_admin;

-- Create test users for each role
CREATE USER contracts_viewer IDENTIFIED BY "viewer_password" 
DEFAULT TABLESPACE contracts_tbs
QUOTA 0 ON contracts_tbs;
GRANT CREATE SESSION TO contracts_viewer;
GRANT contracts_readonly TO contracts_viewer;

CREATE USER contracts_clerk IDENTIFIED BY "clerk_password"
DEFAULT TABLESPACE contracts_tbs
QUOTA 10M ON contracts_tbs;
GRANT CREATE SESSION TO contracts_clerk;
GRANT contracts_operator TO contracts_clerk;

-- Output status
SELECT 'Oracle Contracts Database Setup Complete!' FROM DUAL;
SELECT 'Contracts created: ' || COUNT(*) FROM contracts;
SELECT 'Payments created: ' || COUNT(*) FROM payments;