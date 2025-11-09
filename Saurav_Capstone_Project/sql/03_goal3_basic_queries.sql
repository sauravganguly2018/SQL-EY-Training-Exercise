-- 3.1 List All Active Members
SELECT 
  first_name, 
  last_name, 
  email, 
  membership_type
FROM members
WHERE status = 'active'
ORDER BY last_name, first_name;

-- 3.2 Find Books Published After 2000
SELECT 
  b.title, 
  a.author_name AS author_name, 
  b.publication_year AS pub_year, 
  b.genre
FROM books b
LEFT JOIN authors a ON b.author_id = a.author_id
WHERE b.publication_year >= 2001
ORDER BY b.publication_year DESC;

-- 3.3 Search Books by Genre
SELECT 
  b.title, 
  a.author_name AS author_name, 
  b.genre, 
  COUNT(c.copy_id) AS total_copies
FROM books b
LEFT JOIN authors a ON b.author_id = a.author_id
LEFT JOIN book_copies c ON b.book_id = c.book_id
WHERE b.genre = 'Fiction'
GROUP BY b.book_id, b.title, a.author_name, b.genre
ORDER BY b.title;

-- 3.4 Find Overdue Loans
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  b.title AS book_title,
  l.loan_date,
  l.due_date,
  DATEDIFF(CURDATE(), l.due_date) AS days_overdue
FROM loans l
JOIN members m ON l.member_id = m.member_id
JOIN book_copies c ON l.copy_id = c.copy_id
JOIN books b ON c.book_id = b.book_id
WHERE l.status = 'active' 
  AND l.due_date < CURDATE()
ORDER BY days_overdue DESC;

-- 3.5 Members Who Joined in the Last 6 Months
SELECT 
  first_name, 
  last_name, 
  join_date, 
  membership_type
FROM members
WHERE join_date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY)
ORDER BY join_date DESC;

-- 3.6 Books in Poor Condition
SELECT 
  b.title AS book_title,
  c.copy_number,
  c.condition_status,
  c.acquisition_date
FROM book_copies c
JOIN books b ON c.book_id = b.book_id
WHERE c.condition_status IN ('poor', 'fair')
ORDER BY 
  CASE c.condition_status
    WHEN 'poor' THEN 1
    WHEN 'fair' THEN 2
    ELSE 3
  END,
  c.acquisition_date;

-- 3.7 Top 10 Most Expensive Unpaid Fines
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  f.fine_amount AS fine_amount,
  f.fine_reason AS fine_reason,
  l.loan_date
FROM fines f
JOIN loans l ON f.loan_id = l.loan_id
JOIN members m ON l.member_id = m.member_id
WHERE f.paid = FALSE
ORDER BY f.fine_amount DESC
LIMIT 10;

-- 3.8 Upcoming Events This Month
SELECT 
  event_name,
  event_date,
  event_type,
  max_attendees
FROM events
WHERE event_date > CURDATE()
  AND event_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)
ORDER BY event_date;
