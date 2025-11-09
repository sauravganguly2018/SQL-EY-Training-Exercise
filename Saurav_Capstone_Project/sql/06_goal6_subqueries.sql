-- 6.1 Members with Above-Average Fines
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  SUM(f.fine_amount) AS total_unpaid_fines,
  COUNT(f.fine_id) AS number_of_fines
FROM members m
JOIN loans l ON m.member_id = l.member_id
JOIN fines f ON l.loan_id = f.loan_id
WHERE f.paid = FALSE
GROUP BY m.member_id
HAVING total_unpaid_fines > (
  SELECT AVG(total) 
  FROM (
    SELECT SUM(f2.fine_amount) AS total
    FROM fines f2
    WHERE f2.paid = FALSE
    GROUP BY f2.loan_id
  ) AS sub
)
ORDER BY total_unpaid_fines DESC;

-- 6.2 Books More Popular Than Average
SELECT 
  b.title AS book_title,
  a.author_name AS author,
  COUNT(l.loan_id) AS total_loans,
  (SELECT AVG(book_loans) 
   FROM (
     SELECT COUNT(l2.loan_id) AS book_loans
     FROM loans l2
     JOIN book_copies bc2 ON l2.copy_id = bc2.copy_id
     GROUP BY bc2.book_id
   ) AS avg_sub) AS avg_loans
FROM books b
JOIN authors a ON b.author_id = a.author_id
JOIN book_copies c ON b.book_id = c.book_id
JOIN loans l ON c.copy_id = l.copy_id
GROUP BY b.book_id, b.title, a.author_name
HAVING total_loans > avg_loans
ORDER BY total_loans DESC;

-- 6.3 CTE - Member Borrowing Summary
WITH loan_counts AS (
  SELECT member_id, COUNT(*) AS total_loans
  FROM loans
  GROUP BY member_id
),
fine_totals AS (
  SELECT l.member_id, SUM(f.fine_amount) AS total_fines
  FROM fines f
  JOIN loans l ON f.loan_id = l.loan_id
  GROUP BY l.member_id
),
active_counts AS (
  SELECT member_id, COUNT(*) AS active_loans
  FROM loans
  WHERE status = 'active'
  GROUP BY member_id
)
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  COALESCE(lc.total_loans, 0) AS total_loans,
  COALESCE(ac.active_loans, 0) AS active_loans,
  COALESCE(ft.total_fines, 0) AS total_fines,
  CASE 
    WHEN COALESCE(ac.active_loans, 0) > 0 THEN 'Active Borrower'
    ELSE 'Inactive'
  END AS member_status
FROM members m
LEFT JOIN loan_counts lc ON m.member_id = lc.member_id
LEFT JOIN fine_totals ft ON m.member_id = ft.member_id
LEFT JOIN active_counts ac ON m.member_id = ac.member_id
ORDER BY total_loans DESC;

-- 6.4 Find Books Never Loaned (Subquery Method)
SELECT 
  b.title,
  a.author_name AS author,
  b.genre,
  COUNT(c.copy_id) AS total_copies,
  b.publication_year
FROM books b
JOIN authors a ON b.author_id = a.author_id
LEFT JOIN book_copies c ON b.book_id = c.book_id
WHERE b.book_id NOT IN (
  SELECT DISTINCT bc.book_id
  FROM book_copies bc
  JOIN loans l ON bc.copy_id = l.copy_id
)
GROUP BY b.book_id, b.title, a.author_name, b.genre, b.publication_year
ORDER BY b.publication_year ASC;

-- 6.5 Members Who Attended All Book Club Events
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  COUNT(r.event_id) AS events_attended
FROM members m
JOIN event_registrations r ON m.member_id = r.member_id
JOIN events e ON r.event_id = e.event_id
WHERE e.event_type = 'book_club'
GROUP BY m.member_id
HAVING COUNT(r.event_id) = (
  SELECT COUNT(*) FROM events WHERE event_type = 'book_club'
)
ORDER BY member_name;

-- 6.6 CTE - Monthly Revenue Report (MySQL Compatible)
WITH fine_revenue AS (
  SELECT DATE_FORMAT(payment_date, '%Y-%m') AS month, 
         SUM(fine_amount) AS fine_total
  FROM fines
  WHERE paid = TRUE
  GROUP BY DATE_FORMAT(payment_date, '%Y-%m')
),
membership_revenue AS (
  SELECT DATE_FORMAT(join_date, '%Y-%m') AS month, 
         COUNT(member_id) * 100 AS membership_total
  FROM members
  GROUP BY DATE_FORMAT(join_date, '%Y-%m')
)
SELECT 
  COALESCE(f.month, m.month) AS month,
  COALESCE(f.fine_total, 0) AS fine_revenue,
  COALESCE(m.membership_total, 0) AS membership_revenue,
  COALESCE(f.fine_total, 0) + COALESCE(m.membership_total, 0) AS total_revenue
FROM fine_revenue f
LEFT JOIN membership_revenue m ON f.month = m.month

UNION

SELECT 
  COALESCE(f.month, m.month) AS month,
  COALESCE(f.fine_total, 0) AS fine_revenue,
  COALESCE(m.membership_total, 0) AS membership_revenue,
  COALESCE(f.fine_total, 0) + COALESCE(m.membership_total, 0) AS total_revenue
FROM membership_revenue m
LEFT JOIN fine_revenue f ON m.month = f.month

ORDER BY month DESC
LIMIT 12;

-- 6.7 Correlated Subquery - Loan History
SELECT 
  b.title AS book_title,
  a.author_name AS author,
  (
    SELECT MAX(l2.loan_date)
    FROM loans l2
    JOIN book_copies c2 ON l2.copy_id = c2.copy_id
    WHERE c2.book_id = b.book_id
  ) AS most_recent_loan,
  (
    SELECT CONCAT(m2.first_name, ' ', m2.last_name)
    FROM loans l3
    JOIN members m2 ON l3.member_id = m2.member_id
    JOIN book_copies c3 ON l3.copy_id = c3.copy_id
    WHERE c3.book_id = b.book_id
    ORDER BY l3.loan_date DESC
    LIMIT 1
  ) AS last_borrower
FROM books b
JOIN authors a ON b.author_id = a.author_id
WHERE EXISTS (
  SELECT 1 FROM book_copies c
  JOIN loans l ON c.copy_id = l.copy_id
  WHERE c.book_id = b.book_id
)
ORDER BY most_recent_loan DESC;

-- 6.8 CTE - Book Recommendation Engine
WITH member_fav_genre AS (
  SELECT 
    l.member_id,
    b.genre,
    COUNT(*) AS borrow_count,
    ROW_NUMBER() OVER (PARTITION BY l.member_id ORDER BY COUNT(*) DESC) AS rn
  FROM loans l
  JOIN book_copies c ON l.copy_id = c.copy_id
  JOIN books b ON c.book_id = b.book_id
  GROUP BY l.member_id, b.genre
),
recommended_books AS (
  SELECT b.book_id, b.title, b.genre, a.author_name
  FROM books b
  JOIN authors a ON b.author_id = a.author_id
)
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  g.genre AS favorite_genre,
  rb.title AS recommended_book
FROM members m
JOIN member_fav_genre g ON m.member_id = g.member_id AND g.rn = 1
JOIN recommended_books rb ON rb.genre = g.genre
WHERE rb.book_id NOT IN (
  SELECT c.book_id
  FROM loans l
  JOIN book_copies c ON l.copy_id = c.copy_id
  WHERE l.member_id = m.member_id
)
LIMIT 5;
