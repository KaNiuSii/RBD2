
USE SchoolDB;
GO

INSERT INTO genders (value) VALUES 
('Male'), ('Female'), ('Other');

INSERT INTO years (value) VALUES 
(2023), (2024), (2025);

INSERT INTO teachers (firstName, lastName, birthday, phoneNumber, email, additionalInfo) VALUES 
('John', 'Smith', '1980-05-15', '123-456-7890', 'john.smith@school.edu', 'Mathematics Teacher'),
('Mary', 'Johnson', '1975-08-22', '123-456-7891', 'mary.johnson@school.edu', 'English Teacher'),
('David', 'Brown', '1982-03-10', '123-456-7892', 'david.brown@school.edu', 'Science Teacher'),
('Sarah', 'Davis', '1978-11-30', '123-456-7893', 'sarah.davis@school.edu', 'History Teacher'),
('Michael', 'Wilson', '1985-07-05', '123-456-7894', 'michael.wilson@school.edu', 'Physical Education');

INSERT INTO parents (firstName, lastName, phoneNumber, email) VALUES 
('Robert', 'Anderson', '555-0001', 'robert.anderson@email.com'),
('Jennifer', 'Taylor', '555-0002', 'jennifer.taylor@email.com'),
('William', 'Thomas', '555-0003', 'william.thomas@email.com'),
('Lisa', 'Jackson', '555-0004', 'lisa.jackson@email.com'),
('James', 'White', '555-0005', 'james.white@email.com'),
('Patricia', 'Harris', '555-0006', 'patricia.harris@email.com'),
('Richard', 'Martin', '555-0007', 'richard.martin@email.com'),
('Barbara', 'Thompson', '555-0008', 'barbara.thompson@email.com');

INSERT INTO groups (yearId, home_teacher_id) VALUES 
(1, 1), (1, 2), (2, 3), (2, 4), (3, 5);

INSERT INTO students (groupId, firstName, lastName, birthday, genderId) VALUES 
(1, 'Emma', 'Anderson', '2005-03-15', 2),
(1, 'Liam', 'Johnson', '2005-07-22', 1),
(1, 'Olivia', 'Williams', '2005-09-10', 2),
(2, 'Noah', 'Brown', '2006-01-05', 1),
(2, 'Ava', 'Jones', '2006-04-18', 2),
(3, 'William', 'Garcia', '2007-06-30', 1),
(3, 'Sophia', 'Miller', '2007-08-12', 2),
(4, 'James', 'Davis', '2008-02-25', 1),
(4, 'Isabella', 'Rodriguez', '2008-05-08', 2),
(5, 'Benjamin', 'Martinez', '2009-09-14', 1);

INSERT INTO parents_students (parentId, studentId) VALUES 
(1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
(6, 6), (7, 7), (8, 8), (1, 9), (2, 10);

INSERT INTO classrooms (location) VALUES 
('Room 101'), ('Room 102'), ('Room 103'), ('Room 201'), ('Room 202'), 
('Laboratory A'), ('Laboratory B'), ('Gymnasium'), ('Library'), ('Auditorium');

INSERT INTO subjects (shortName, longName) VALUES 
('MATH', 'Mathematics'),
('ENG', 'English Literature'),
('SCI', 'Science'),
('HIST', 'History'),
('PE', 'Physical Education'),
('ART', 'Art'),
('MUS', 'Music'),
('COMP', 'Computer Science');

INSERT INTO marks (subjectId, studentId, value, comment, weight) VALUES 
(1, 1, 85, 'Good understanding of algebra', 1),
(1, 2, 92, 'Excellent problem-solving skills', 1),
(2, 1, 78, 'Needs improvement in writing', 1),
(2, 2, 88, 'Strong analytical reading', 1),
(3, 3, 95, 'Outstanding lab work', 2),
(3, 4, 82, 'Good theoretical knowledge', 1),
(4, 5, 90, 'Excellent essay writing', 2),
(5, 6, 87, 'Great athletic performance', 1);

INSERT INTO hours (start_hour, start_minutes, end_hour, end_minutes) VALUES 
(8, 0, 8, 45),
(9, 0, 9, 45),
(10, 0, 10, 45),
(11, 0, 11, 45),
(12, 0, 12, 45),
(13, 0, 13, 45),
(14, 0, 14, 45),
(15, 0, 15, 45);

INSERT INTO days (value) VALUES 
('Monday'), ('Tuesday'), ('Wednesday'), ('Thursday'), ('Friday');

INSERT INTO lessons (teacherId, subjectId, groupId, hourId, classroomId, dayId) VALUES 
(1, 1, 1, 1, 1, 1),
(2, 2, 1, 2, 2, 1),
(3, 3, 2, 3, 6, 2),
(4, 4, 2, 4, 3, 2),
(5, 5, 3, 5, 8, 3),
(1, 1, 2, 1, 1, 4),
(2, 2, 3, 2, 2, 4),
(3, 3, 1, 3, 7, 5);

INSERT INTO attendances (dateTimeChecked, lessonId) VALUES 
('2024-01-15 08:00:00', 1),
('2024-01-15 09:00:00', 2),
('2024-01-16 10:00:00', 3),
('2024-01-16 11:00:00', 4),
('2024-01-17 12:00:00', 5);

INSERT INTO attendance_student (attendanceId, studentId, present) VALUES 
(1, 1, 1), (1, 2, 1), (1, 3, 0),
(2, 1, 1), (2, 2, 1), (2, 3, 1),
(3, 4, 1), (3, 5, 0),
(4, 4, 1), (4, 5, 1),
(5, 6, 1), (5, 7, 1);

PRINT 'MSSQL Sample data inserted successfully!';
