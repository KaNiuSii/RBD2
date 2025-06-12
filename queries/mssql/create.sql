CREATE DATABASE RBD;
use RBD;

CREATE TABLE users (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    username        VARCHAR(50) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    email           VARCHAR(100) UNIQUE NOT NULL,
    role            VARCHAR(20) NOT NULL CHECK (role IN ('student', 'teacher', 'parent', 'admin')),
    active          BIT DEFAULT 1,
    created_at      DATETIME2 DEFAULT GETDATE(),
    last_login      DATETIME2
);

-- Academic subjects
CREATE TABLE subjects (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    code            VARCHAR(10) UNIQUE NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    active          BIT DEFAULT 1
);

-- Physical classrooms and facilities
CREATE TABLE classrooms (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    building        VARCHAR(50) NOT NULL,
    room_number     VARCHAR(20) NOT NULL,
    capacity        INT NOT NULL,
    equipment       TEXT,
    active          BIT DEFAULT 1,
    UNIQUE(building, room_number)
);

-- Scheduled lessons (simplified from original)
CREATE TABLE lessons (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    subject_id      INT NOT NULL REFERENCES subjects(id),
    teacher_user_id INT NOT NULL REFERENCES users(id),
    classroom_id    INT NOT NULL REFERENCES classrooms(id),
    lesson_datetime DATETIME2 NOT NULL,
    duration_minutes INT DEFAULT 45,
    status          VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'cancelled')),
    notes           TEXT
);
