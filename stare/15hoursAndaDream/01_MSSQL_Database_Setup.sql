CREATE DATABASE SchoolDB;
GO

USE SchoolDB;
GO

CREATE TABLE genders (
    id int IDENTITY(1,1) PRIMARY KEY,
    value nvarchar(50) NOT NULL
);

CREATE TABLE years (
    id int IDENTITY(1,1) PRIMARY KEY,
    value int NOT NULL
);

CREATE TABLE teachers (
    id int IDENTITY(1,1) PRIMARY KEY,
    firstName nvarchar(100) NOT NULL,
    lastName nvarchar(100) NOT NULL,
    birthday date,
    phoneNumber nvarchar(20),
    email nvarchar(100),
    additionalInfo nvarchar(500)
);

CREATE TABLE parents (
    id int IDENTITY(1,1) PRIMARY KEY,
    firstName nvarchar(100) NOT NULL,
    lastName nvarchar(100) NOT NULL,
    phoneNumber nvarchar(20),
    email nvarchar(100)
);

CREATE TABLE groups (
    id int IDENTITY(1,1) PRIMARY KEY,
    yearId int NOT NULL,
    home_teacher_id int NOT NULL,
    FOREIGN KEY (yearId) REFERENCES years(id),
    FOREIGN KEY (home_teacher_id) REFERENCES teachers(id)
);

CREATE TABLE students (
    id int IDENTITY(1,1) PRIMARY KEY,
    groupId int NOT NULL,
    firstName nvarchar(100) NOT NULL,
    lastName nvarchar(100) NOT NULL,
    birthday date,
    genderId int,
    FOREIGN KEY (groupId) REFERENCES groups(id),
    FOREIGN KEY (genderId) REFERENCES genders(id)
);

CREATE TABLE parents_students (
    id int IDENTITY(1,1) PRIMARY KEY,
    parentId int NOT NULL,
    studentId int NOT NULL,
    FOREIGN KEY (parentId) REFERENCES parents(id),
    FOREIGN KEY (studentId) REFERENCES students(id)
);

CREATE TABLE classrooms (
    id int IDENTITY(1,1) PRIMARY KEY,
    location nvarchar(100) NOT NULL
);

CREATE TABLE subjects (
    id int IDENTITY(1,1) PRIMARY KEY,
    shortName nvarchar(10) NOT NULL,
    longName nvarchar(100) NOT NULL
);

CREATE TABLE marks (
    id int IDENTITY(1,1) PRIMARY KEY,
    subjectId int NOT NULL,
    studentId int NOT NULL,
    value int NOT NULL,
    comment nvarchar(500),
    weight int DEFAULT 1,
    FOREIGN KEY (subjectId) REFERENCES subjects(id),
    FOREIGN KEY (studentId) REFERENCES students(id)
);

CREATE TABLE hours (
    id int IDENTITY(1,1) PRIMARY KEY,
    start_hour int NOT NULL,
    start_minutes int NOT NULL,
    end_hour int NOT NULL,
    end_minutes int NOT NULL
);

CREATE TABLE days (
    id int IDENTITY(1,1) PRIMARY KEY,
    value nvarchar(20) NOT NULL
);

CREATE TABLE lessons (
    id int IDENTITY(1,1) PRIMARY KEY,
    teacherId int NOT NULL,
    subjectId int NOT NULL,
    groupId int NOT NULL,
    hourId int NOT NULL,
    classroomId int NOT NULL,
    dayId int NOT NULL,
    FOREIGN KEY (teacherId) REFERENCES teachers(id),
    FOREIGN KEY (subjectId) REFERENCES subjects(id),
    FOREIGN KEY (groupId) REFERENCES groups(id),
    FOREIGN KEY (hourId) REFERENCES hours(id),
    FOREIGN KEY (classroomId) REFERENCES classrooms(id),
    FOREIGN KEY (dayId) REFERENCES days(id)
);

CREATE TABLE attendances (
    id int IDENTITY(1,1) PRIMARY KEY,
    dateTimeChecked datetime NOT NULL,
    lessonId int NOT NULL,
    FOREIGN KEY (lessonId) REFERENCES lessons(id)
);

CREATE TABLE attendance_student (
    id int IDENTITY(1,1) PRIMARY KEY,
    attendanceId int NOT NULL,
    studentId int NOT NULL,
    present bit NOT NULL,
    FOREIGN KEY (attendanceId) REFERENCES attendances(id),
    FOREIGN KEY (studentId) REFERENCES students(id)
);

PRINT 'MSSQL School Database schema created successfully!';
