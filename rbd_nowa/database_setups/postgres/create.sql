CREATE SCHEMA remarks_main;

CREATE USER remarks_user WITH PASSWORD 'Remarks123';

GRANT USAGE ON SCHEMA remarks_main TO remarks_user;

CREATE TABLE remarks_main.remark (
    id SERIAL PRIMARY KEY,
    studentId INTEGER NOT NULL,
    teacherId INTEGER NOT NULL,
    value TEXT NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_remark_student ON remarks_main.remark(studentId);
CREATE INDEX idx_remark_teacher ON remarks_main.remark(teacherId);
CREATE INDEX idx_remark_date ON remarks_main.remark(created_date);
