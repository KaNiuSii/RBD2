-- Create roles for different access levels
CREATE ROLE remarks_readonly;
CREATE ROLE remarks_teacher;
CREATE ROLE remarks_admin;

-- Grant permissions to readonly role
GRANT USAGE ON SCHEMA remarks TO remarks_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA remarks TO remarks_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA remarks TO remarks_readonly;

-- Grant permissions to teacher role
GRANT remarks_readonly TO remarks_teacher;
GRANT INSERT ON remarks.remark TO remarks_teacher;
GRANT EXECUTE ON FUNCTION add_remark(INTEGER, INTEGER, TEXT, VARCHAR, VARCHAR) TO remarks_teacher;
GRANT EXECUTE ON FUNCTION get_student_remarks(INTEGER) TO remarks_teacher;
GRANT EXECUTE ON FUNCTION get_teacher_remarks(INTEGER) TO remarks_teacher;

-- Grant permissions to admin role
GRANT remarks_teacher TO remarks_admin;
GRANT ALL ON ALL TABLES IN SCHEMA remarks TO remarks_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA remarks TO remarks_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA remarks TO remarks_admin;

-- Create sample users
CREATE USER teacher_user WITH PASSWORD 'teacher_password';
GRANT remarks_teacher TO teacher_user;

CREATE USER admin_user WITH PASSWORD 'admin_password';
GRANT remarks_admin TO admin_user;