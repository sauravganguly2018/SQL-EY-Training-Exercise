-- 5.1 Complete Loan History with Details
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  m.email,
  b.title AS book_title,
  a.author_name AS author,
  l.loan_date,
  l.due_date,
  l.return_date,
  l.status
FROM loans l
JOIN members m ON l.member_id = m.member_id
JOIN book_copies c ON l.copy_id = c.copy_id
JOIN books b ON c.book_id = b.book_id
JOIN authors a ON b.author_id = a.author_id
ORDER BY l.loan_date DESC
LIMIT 20;

-- 5.2 Books Currently On Loan
SELECT 
  b.title AS book_title,
  a.author_name AS author,
  c.copy_number,
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  l.loan_date,
  l.due_date,
  DATEDIFF(l.due_date, CURDATE()) AS days_until_due
FROM loans l
JOIN book_copies c ON l.copy_id = c.copy_id
JOIN books b ON c.book_id = b.book_id
JOIN authors a ON b.author_id = a.author_id
JOIN members m ON l.member_id = m.member_id
WHERE l.status = 'active'
ORDER BY l.due_date ASC;

-- 5.3 Members with Overdue Books and Fines
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  m.email,
  m.phone,
  COUNT(DISTINCT l.loan_id) AS overdue_books,
  SUM(f.fine_amount) AS total_unpaid_fines
FROM members m
JOIN loans l ON m.member_id = l.member_id
JOIN fines f ON l.loan_id = f.loan_id
WHERE f.paid = FALSE
GROUP BY m.member_id
ORDER BY total_unpaid_fines DESC;

-- 5.4 Book Availability Report
SELECT 
  b.title AS book_title,
  a.author_name AS author,
  COUNT(c.copy_id) AS total_copies,
  COUNT(CASE WHEN l.status = 'active' THEN 1 END) AS copies_on_loan,
  COUNT(c.copy_id) - COUNT(CASE WHEN l.status = 'active' THEN 1 END) AS available_copies
FROM books b
JOIN authors a ON b.author_id = a.author_id
LEFT JOIN book_copies c ON b.book_id = c.book_id
LEFT JOIN loans l ON c.copy_id = l.copy_id AND l.status = 'active'
GROUP BY b.book_id, b.title, a.author_name
ORDER BY available_copies ASC;

-- 5.5 Event Attendance List
SELECT 
  e.event_name,
  e.event_date,
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  m.email,
  r.registration_date
FROM events e
JOIN event_registrations r ON e.event_id = r.event_id
JOIN members m ON r.member_id = m.member_id
WHERE e.event_date >= CURDATE()
ORDER BY e.event_date, m.last_name;

-- 5.6 Author Popularity Report
SELECT 
  a.author_name AS author,
  COUNT(DISTINCT b.book_id) AS book_count,
  COUNT(l.loan_id) AS total_loans,
  ROUND(COUNT(l.loan_id) / COUNT(DISTINCT b.book_id), 2) AS avg_loans_per_book
FROM authors a
JOIN books b ON a.author_id = b.author_id
JOIN book_copies c ON b.book_id = c.book_id
JOIN loans l ON c.copy_id = l.copy_id
GROUP BY a.author_id, a.author_name
HAVING total_loans > 0
ORDER BY total_loans DESC
LIMIT 10;

-- 5.7 Members Who Never Borrowed
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  m.email,
  m.join_date,
  m.membership_type
FROM members m
LEFT JOIN loans l ON m.member_id = l.member_id
WHERE l.loan_id IS NULL
ORDER BY m.join_date ASC;

-- 5.8 Self-Join - Members from Same Address
SELECT 
  CONCAT(m1.first_name, ' ', m1.last_name) AS member_1,
  CONCAT(m2.first_name, ' ', m2.last_name) AS member_2,
  m1.address AS shared_address
FROM members m1
JOIN members m2 
  ON m1.address = m2.address
  AND m1.member_id < m2.member_id
ORDER BY m1.address;
