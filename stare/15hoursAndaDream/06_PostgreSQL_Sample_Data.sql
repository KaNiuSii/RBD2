
SET search_path TO remarks_main, remarks_remote1, remarks_remote2, public;

INSERT INTO remarks_main.remark (studentId, teacherId, value) VALUES 
(1, 1, 'Excellent performance in mathematics. Shows great potential in problem-solving.'),
(1, 2, 'Good participation in English class. Needs to work on grammar.'),
(2, 1, 'Outstanding mathematical abilities. Helps other students with complex problems.'),
(2, 3, 'Shows great interest in science experiments. Very curious and engaged.'),
(3, 2, 'Creative writing skills are developing well. Participates actively in discussions.'),
(3, 4, 'Good understanding of historical concepts. Asks thoughtful questions.'),
(4, 1, 'Struggles with advanced mathematics. Recommend additional tutoring.'),
(4, 5, 'Excellent athletic performance. Shows leadership qualities in team sports.'),
(5, 2, 'Strong reading comprehension skills. Enjoys literature discussions.'),
(5, 3, 'Methodical approach to science labs. Produces detailed reports.'),
(6, 1, 'Improving steadily in mathematics. Good effort and dedication.'),
(6, 4, 'Enthusiastic about history projects. Good research skills.'),
(7, 2, 'Quiet student but produces quality written work. Encourage more participation.'),
(7, 3, 'Careful and precise in laboratory work. Follows safety protocols well.'),
(8, 1, 'Quick learner in mathematics. Could benefit from more challenging problems.'),
(8, 5, 'Natural athlete with good coordination. Positive team player.'),
(9, 2, 'Developing writing skills. Shows improvement in recent assignments.'),
(9, 4, 'Interested in ancient civilizations. Asks detailed questions about historical events.'),
(10, 1, 'Shows potential in mathematics but needs to focus more in class.'),
(10, 3, 'Curious about nature and science. Enjoys outdoor learning activities.');

INSERT INTO remarks_remote1.remark_archive (studentId, teacherId, value, created_date, archived_date) VALUES 
(1, 1, 'Previous semester: Good foundation in basic mathematics.', '2023-12-15 10:30:00', '2024-01-01 09:00:00'),
(1, 2, 'Previous semester: Needs to improve reading speed.', '2023-12-10 14:20:00', '2024-01-01 09:00:00'),
(2, 1, 'Previous semester: Exceptional problem-solving skills.', '2023-12-20 11:15:00', '2024-01-01 09:00:00'),
(3, 2, 'Previous semester: Creative approach to assignments.', '2023-12-05 16:45:00', '2024-01-01 09:00:00'),
(4, 1, 'Previous semester: Required extra help with fractions.', '2023-12-18 13:30:00', '2024-01-01 09:00:00'),
(5, 3, 'Previous semester: Excellent lab partner and collaborator.', '2023-12-12 09:20:00', '2024-01-01 09:00:00');

REFRESH MATERIALIZED VIEW remarks_main.mv_student_remark_stats;

INSERT INTO remarks_main.remark (studentId, teacherId, value) VALUES 
(1, 3, 'Shows interest in science demonstrations. Asks good follow-up questions.'),
(2, 4, 'Demonstrates good understanding of historical timelines and cause-effect relationships.'),
(3, 5, 'Good coordination and teamwork in physical education activities.');

SELECT 'Cross-schema query example:' as info;
SELECT * FROM remarks_main.get_student_remarks(1) LIMIT 5;

SELECT 'Simulated FDW query example:' as info;
SELECT * FROM remarks_main.simulate_fdw_query('remarks_remote1', 'remark_archive', 1);

SELECT 'Materialized view results:' as info;
SELECT * FROM remarks_main.mv_student_remark_stats ORDER BY studentId LIMIT 5;

SELECT 'Distributed view results:' as info;
SELECT * FROM remarks_main.distributed_remarks WHERE studentId = 1 ORDER BY created_date;

