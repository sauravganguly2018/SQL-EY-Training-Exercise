-- 7.1 All People in the System
SELECT CONCAT(first_name, ' ', last_name) AS full_name, email, 'Member' AS type
FROM members
UNION
SELECT author_name AS full_name, NULL AS email, 'Author' AS type
FROM authors
ORDER BY type, full_name;


-- 7.2 Comprehensive Activity Log
SELECT 'Loan' AS activity_type, loan_date AS activity_date, 
       CONCAT(m.first_name, ' ', m.last_name) AS person, b.title AS description
FROM loans l
JOIN members m ON l.member_id = m.member_id
JOIN book_copies bc ON l.copy_id = bc.copy_id
JOIN books b ON bc.book_id = b.book_id
UNION ALL
SELECT 'Event' AS activity_type, event_date AS activity_date, 
       NULL AS person, event_name AS description
FROM events
UNION ALL
SELECT 'Registration' AS activity_type, registration_date AS activity_date, 
       CONCAT(m.first_name, ' ', m.last_name) AS person, e.event_name AS description
FROM event_registrations r
JOIN members m ON r.member_id = m.member_id
JOIN events e ON r.event_id = e.event_id
ORDER BY activity_date DESC
LIMIT 50;


-- 7.3 Books Available vs Currently Loaned
SELECT title, status, total
FROM (
  SELECT b.title AS title, 'Available' AS status, COUNT(bc.copy_id) AS total
  FROM books b
  JOIN book_copies bc ON b.book_id = bc.book_id
  WHERE bc.copy_id NOT IN (
    SELECT copy_id FROM loans WHERE status = 'active'
  )
  GROUP BY b.title

  UNION ALL

  SELECT b.title AS title, 'On Loan' AS status, COUNT(l.copy_id) AS total
  FROM books b
  JOIN book_copies bc ON b.book_id = bc.book_id
  JOIN loans l ON bc.copy_id = l.copy_id
  WHERE l.status = 'active'
  GROUP BY b.title
) AS combined
ORDER BY title;


-- 7.4 Members with Issues
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name, 
  m.email, 
  'Overdue' AS issue_type, 
  COUNT(*) AS issue_count
FROM loans l
JOIN members m ON l.member_id = m.member_id
WHERE l.due_date < CURDATE() 
  AND l.status = 'active'
GROUP BY m.member_id

UNION

SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  m.email,
  'Unpaid Fines' AS issue_type,
  COUNT(*) AS issue_count
FROM fines f
JOIN loans l ON f.loan_id = l.loan_id     
JOIN members m ON l.member_id = m.member_id 
WHERE f.paid = FALSE
GROUP BY m.member_id

UNION

SELECT 
  CONCAT(first_name, ' ', last_name) AS member_name, 
  email, 
  'Suspended' AS issue_type, 
  1 AS issue_count
FROM members
WHERE status = 'suspended'

ORDER BY member_name;


-- 7.5 Popular vs Unpopular Books
(
  SELECT 
    b.title, 
    a.author_name AS author, 
    'Popular' AS category, 
    COUNT(l.loan_id) AS loan_count
  FROM books b
  JOIN authors a ON b.author_id = a.author_id
  JOIN book_copies bc ON b.book_id = bc.book_id
  JOIN loans l ON bc.copy_id = l.copy_id
  GROUP BY b.book_id, a.author_name
  ORDER BY loan_count DESC
  LIMIT 10
)
UNION ALL
(
  SELECT 
    b.title, 
    a.author_name AS author, 
    'Unpopular' AS category, 
    COUNT(l.loan_id) AS loan_count
  FROM books b
  JOIN authors a ON b.author_id = a.author_id
  JOIN book_copies bc ON b.book_id = bc.book_id
  LEFT JOIN loans l ON bc.copy_id = l.copy_id
  GROUP BY b.book_id, a.author_name
  ORDER BY loan_count ASC
  LIMIT 10
)
ORDER BY category, loan_count;
