-- Create the main school management database
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SchoolManagement')
BEGIN
    ALTER DATABASE SchoolManagement SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SchoolManagement;
END
GO

-- Create the main school management database
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'SchoolManagement')
BEGIN
    ALTER DATABASE SchoolManagement SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SchoolManagement;
END
GO

--Idk if this is needed, I used create database without any parameters for now
CREATE DATABASE SchoolManagement
ON 
( NAME = 'SchoolManagement_Data',
  FILENAME = 'C:\Database\SchoolManagement_Data.mdf',
  SIZE = 1GB,
  MAXSIZE = 10GB,
  FILEGROWTH = 100MB )
LOG ON 
( NAME = 'SchoolManagement_Log',
  FILENAME = 'C:\Database\SchoolManagement_Log.ldf',
  SIZE = 100MB,
  MAXSIZE = 1GB,
  FILEGROWTH = 10MB );
GO

USE SchoolManagement;
GO

-- Create Gender lookup table
CREATE TABLE genders (
    id INT IDENTITY(1,1) PRIMARY KEY,
    value NVARCHAR(20) NOT NULL UNIQUE
);

-- Create Years table
CREATE TABLE years (
    id INT IDENTITY(1,1) PRIMARY KEY,
    value INT NOT NULL UNIQUE
);

-- Create Teachers table
CREATE TABLE teachers (
    id INT IDENTITY(1,1) PRIMARY KEY,
    firstName NVARCHAR(50) NOT NULL,
    lastName NVARCHAR(50) NOT NULL,
    birthday DATE NOT NULL,
    phoneNumber NVARCHAR(20),
    email NVARCHAR(100),
    additionalInfo NVARCHAR(500)
);

-- Create Groups table
CREATE TABLE groups (
    id INT IDENTITY(1,1) PRIMARY KEY,
    yearId INT NOT NULL,
    home_teacher_id INT NOT NULL,
    FOREIGN KEY (yearId) REFERENCES years(id),
    FOREIGN KEY (home_teacher_id) REFERENCES teachers(id)
);

-- Create Students table
CREATE TABLE students (
    id INT IDENTITY(1,1) PRIMARY KEY,
    groupId INT NOT NULL,
    firstName NVARCHAR(50) NOT NULL,
    lastName NVARCHAR(50) NOT NULL,
    birthday DATE NOT NULL,
    genderId INT NOT NULL,
    FOREIGN KEY (groupId) REFERENCES groups(id),
    FOREIGN KEY (genderId) REFERENCES genders(id)
);

-- Create Parents table
CREATE TABLE parents (
    id INT IDENTITY(1,1) PRIMARY KEY,
    firstName NVARCHAR(50) NOT NULL,
    lastName NVARCHAR(50) NOT NULL,
    phoneNumber NVARCHAR(20),
    email NVARCHAR(100)
);

-- Create Parents-Students relationship table
CREATE TABLE parents_students (
    id INT IDENTITY(1,1) PRIMARY KEY,
    parentId INT NOT NULL,
    studentId INT NOT NULL,
    FOREIGN KEY (parentId) REFERENCES parents(id),
    FOREIGN KEY (studentId) REFERENCES students(id),
    UNIQUE(parentId, studentId)
);

-- Create Classrooms table
CREATE TABLE classrooms (
    id INT IDENTITY(1,1) PRIMARY KEY,
    location NVARCHAR(100) NOT NULL
);

-- Create Subjects table
CREATE TABLE subjects (
    id INT IDENTITY(1,1) PRIMARY KEY,
    shortName NVARCHAR(10) NOT NULL,
    longName NVARCHAR(100) NOT NULL
);

-- Create Hours table
CREATE TABLE hours (
    id INT IDENTITY(1,1) PRIMARY KEY,
    start_hour INT NOT NULL CHECK (start_hour >= 0 AND start_hour <= 23),
    start_minutes INT NOT NULL CHECK (start_minutes >= 0 AND start_minutes <= 59),
    end_hour INT NOT NULL CHECK (end_hour >= 0 AND end_hour <= 23),
    end_minutes INT NOT NULL CHECK (end_minutes >= 0 AND end_minutes <= 59)
);

-- Create Days table
CREATE TABLE days (
    id INT IDENTITY(1,1) PRIMARY KEY,
    value NVARCHAR(20) NOT NULL UNIQUE
);

-- Create Lessons table
CREATE TABLE lessons (
    id INT IDENTITY(1,1) PRIMARY KEY,
    teacherId INT NOT NULL,
    subjectId INT NOT NULL,
    groupId INT NOT NULL,
    hourId INT NOT NULL,
    classroomId INT NOT NULL,
    dayId INT NOT NULL,
    FOREIGN KEY (teacherId) REFERENCES teachers(id),
    FOREIGN KEY (subjectId) REFERENCES subjects(id),
    FOREIGN KEY (groupId) REFERENCES groups(id),
    FOREIGN KEY (hourId) REFERENCES hours(id),
    FOREIGN KEY (classroomId) REFERENCES classrooms(id),
    FOREIGN KEY (dayId) REFERENCES days(id)
);

-- Create Marks table
CREATE TABLE marks (
    id INT IDENTITY(1,1) PRIMARY KEY,
    subjectId INT NOT NULL,
    studentId INT NOT NULL,
    value INT NOT NULL CHECK (value >= 1 AND value <= 6),
    comment NVARCHAR(500),
    weight INT DEFAULT 1 CHECK (weight > 0),
    date_created DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (subjectId) REFERENCES subjects(id),
    FOREIGN KEY (studentId) REFERENCES students(id)
);

-- Create Attendances table
CREATE TABLE attendances (
    id INT IDENTITY(1,1) PRIMARY KEY,
    dateTimeChecked DATETIME NOT NULL,
    lessonId INT NOT NULL,
    FOREIGN KEY (lessonId) REFERENCES lessons(id)
);

-- Create Attendance_Student table
CREATE TABLE attendance_student (
    id INT IDENTITY(1,1) PRIMARY KEY,
    attendanceId INT NOT NULL,
    studentId INT NOT NULL,
    present BIT NOT NULL DEFAULT 1,
    FOREIGN KEY (attendanceId) REFERENCES attendances(id),
    FOREIGN KEY (studentId) REFERENCES students(id),
    UNIQUE(attendanceId, studentId)
);

-- Create indexes for better performance
CREATE INDEX IX_Students_GroupId ON students(groupId);
CREATE INDEX IX_Students_GenderId ON students(genderId);
CREATE INDEX IX_Marks_StudentId ON marks(studentId);
CREATE INDEX IX_Marks_SubjectId ON marks(subjectId);
CREATE INDEX IX_Lessons_TeacherId ON lessons(teacherId);
CREATE INDEX IX_Lessons_GroupId ON lessons(groupId);
CREATE INDEX IX_Attendance_LessonId ON attendances(lessonId);
CREATE INDEX IX_AttendanceStudent_StudentId ON attendance_student(studentId);