-- Generate sample remarks data
DO $$
DECLARE
    i INTEGER;
    student_ids INTEGER[] := ARRAY[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20];
    teacher_ids INTEGER[] := ARRAY[1,2,3,4,5,6,7,8,9,10];
    severities VARCHAR(20)[] := ARRAY['INFO', 'WARNING', 'SERIOUS', 'CRITICAL'];
    categories VARCHAR(50)[] := ARRAY['ACADEMIC', 'BEHAVIORAL', 'ATTENDANCE', 'GENERAL'];
    sample_remarks TEXT[] := ARRAY[
        'Excellent participation in class discussion',
        'Late to class multiple times this week',
        'Outstanding performance on recent assignment',
        'Disruptive behavior during lesson',
        'Improved significantly in mathematics',
        'Absent without valid excuse',
        'Helpful to other students during group work',
        'Incomplete homework submissions',
        'Demonstrated leadership skills',
        'Needs additional support in reading',
        'Consistently punctual and prepared',
        'Inappropriate language used in class',
        'Creative thinking in problem solving',
        'Difficulty focusing during lessons',
        'Positive attitude and enthusiasm'
    ];
    random_student INTEGER;
    random_teacher INTEGER;
    random_severity VARCHAR(20);
    random_category VARCHAR(50);
    random_remark TEXT;
    random_days INTEGER;
BEGIN
    -- Generate 100 sample remarks
    FOR i IN 1..100 LOOP
        -- Select random values
        random_student := student_ids[1 + (random() * (array_length(student_ids, 1) - 1))::INTEGER];
        random_teacher := teacher_ids[1 + (random() * (array_length(teacher_ids, 1) - 1))::INTEGER];
        random_severity := severities[1 + (random() * (array_length(severities, 1) - 1))::INTEGER];
        random_category := categories[1 + (random() * (array_length(categories, 1) - 1))::INTEGER];
        random_remark := sample_remarks[1 + (random() * (array_length(sample_remarks, 1) - 1))::INTEGER];
        random_days := (random() * 60)::INTEGER; -- Random date within last 60 days
        
        -- Insert remark
        INSERT INTO remarks.remark (
            studentId, 
            teacherId, 
            value, 
            severity, 
            category, 
            created_date
        ) VALUES (
            random_student,
            random_teacher,
            random_remark,
            random_severity,
            random_category,
            CURRENT_TIMESTAMP - (random_days || ' days')::INTERVAL
        );
    END LOOP;
    
    RAISE NOTICE 'Inserted % sample remarks', i-1;
END $$;

-- Refresh the materialized view
REFRESH MATERIALIZED VIEW remarks.mv_remarks_statistics;