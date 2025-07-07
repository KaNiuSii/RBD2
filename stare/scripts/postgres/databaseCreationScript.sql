-- Connect as a superuser (postgres)
-- Create database for remarks system
CREATE DATABASE remarks_system;

-- Connect to the new database
\c remarks_system;

-- Create a dedicated user for the remarks system
CREATE USER remarks_admin WITH PASSWORD 'secure_password';

-- Grant necessary privileges
GRANT ALL PRIVILEGES ON DATABASE remarks_system TO remarks_admin;

-- Create schema for better organization
CREATE SCHEMA remarks;
GRANT ALL ON SCHEMA remarks TO remarks_admin;

-- Set default schema for the user
ALTER USER remarks_admin SET search_path TO remarks, public;

-- Switch to remarks_admin user
SET ROLE remarks_admin;

-- Create the remarks table
CREATE TABLE remarks.remark (
    id SERIAL PRIMARY KEY,
    studentId INTEGER NOT NULL,
    teacherId INTEGER NOT NULL,
    value TEXT NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    severity VARCHAR(20) DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'SERIOUS', 'CRITICAL')),
    category VARCHAR(50) DEFAULT 'GENERAL' CHECK (category IN ('ACADEMIC', 'BEHAVIORAL', 'ATTENDANCE', 'GENERAL'))
);

-- Create indexes for better performance
CREATE INDEX idx_remark_student ON remarks.remark(studentId);
CREATE INDEX idx_remark_teacher ON remarks.remark(teacherId);
CREATE INDEX idx_remark_date ON remarks.remark(created_date);
CREATE INDEX idx_remark_severity ON remarks.remark(severity);
CREATE INDEX idx_remark_category ON remarks.remark(category);