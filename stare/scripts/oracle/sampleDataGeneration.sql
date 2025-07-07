-- Create a procedure to generate sample contracts and payments
CREATE OR REPLACE PROCEDURE generate_sample_data AS
    v_contract_id NUMBER;
    v_start_date DATE;
    v_end_date DATE;
    v_monthly_amount DECIMAL(10,2);
    v_student_id NUMBER;
    v_parent_id NUMBER;
    v_student_parent_pairs SYS.DBMS_SQL.NUMBER_TABLE;
    v_count NUMBER := 0;
    
    -- Cursor to get student-parent pairs from MSSQL
    CURSOR c_student_parents IS
        SELECT ps.studentId, ps.parentId
        FROM parents_students@mssql_link ps;
    
BEGIN
    -- Get student-parent pairs
    FOR pair IN c_student_parents LOOP
        v_count := v_count + 1;
        IF v_count <= 50 THEN  -- Limit to 50 contracts for sample data
            v_student_id := pair.studentId;
            v_parent_id := pair.parentId;
            
            -- Generate random contract data
            v_start_date := ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -FLOOR(DBMS_RANDOM.VALUE(0, 12)));
            v_end_date := ADD_MONTHS(v_start_date, 12); -- 1-year contract
            v_monthly_amount := ROUND(DBMS_RANDOM.VALUE(100, 500), 2);
            
            -- Insert contract
            SELECT contracts_seq.NEXTVAL INTO v_contract_id FROM DUAL;
            
            INSERT INTO contracts (
                id,
                studentId,
                parentId,
                startDate,
                endDate,
                monthlyAmount
            ) VALUES (
                v_contract_id,
                v_student_id,
                v_parent_id,
                v_start_date,
                v_end_date,
                v_monthly_amount
            );
            
            -- Generate payment records
            FOR i IN 0..11 LOOP  -- 12 monthly payments
                INSERT INTO payments (
                    id,
                    contractId,
                    dueDate,
                    paidDate,
                    amount,
                    status
                ) VALUES (
                    payments_seq.NEXTVAL,
                    v_contract_id,
                    ADD_MONTHS(v_start_date, i),
                    CASE 
                        WHEN i <= 6 THEN ADD_MONTHS(v_start_date, i) + FLOOR(DBMS_RANDOM.VALUE(1, 5))  -- Paid for first 6 months
                        ELSE NULL  -- Not paid for remaining months
                    END,
                    v_monthly_amount,
                    CASE 
                        WHEN i <= 6 THEN 'PAID'  -- Paid for first 6 months
                        WHEN ADD_MONTHS(v_start_date, i) < SYSDATE THEN 'OVERDUE'  -- Overdue if past due date
                        ELSE 'PENDING'  -- Pending for future months
                    END
                );
            END LOOP;
        END IF;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Sample data generated: ' || v_count || ' contracts');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error generating sample data: ' || SQLERRM);
END;
/

-- Execute the sample data generation
BEGIN
    generate_sample_data;
END;
/