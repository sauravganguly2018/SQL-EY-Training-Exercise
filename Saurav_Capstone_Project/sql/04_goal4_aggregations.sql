-- 4.1 Count Members by Membership Type
SELECT 
  membership_type,
  COUNT(*) AS member_count,
  ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM members)), 2) AS percentage
FROM members
GROUP BY membership_type
ORDER BY member_count DESC;

-- 4.2 Total Fines Collected vs Outstanding
SELECT 
  CASE WHEN paid = TRUE THEN 'Collected' ELSE 'Outstanding' END AS payment_status,
  SUM(fine_amount) AS total_amount,
  COUNT(*) AS fine_count
FROM fines
GROUP BY paid
UNION ALL
SELECT 
  'Overall Total',
  SUM(fine_amount),
  COUNT(*)
FROM fines;

-- 4.3 Most Popular Genres
SELECT 
  b.genre,
  COUNT(DISTINCT b.book_id) AS number_of_titles,
  SUM(b.total_copies) AS total_copies
FROM books b
GROUP BY b.genre
ORDER BY total_copies DESC
LIMIT 5;

-- 4.4 Average Loan Duration by Member Type
SELECT 
  m.membership_type,
  ROUND(AVG(DATEDIFF(l.return_date, l.loan_date)), 1) AS avg_loan_days,
  COUNT(l.loan_id) AS total_loans
FROM loans l
JOIN members m ON l.member_id = m.member_id
WHERE l.status = 'returned'
GROUP BY m.membership_type
ORDER BY avg_loan_days DESC;

-- 4.5 Books Never Borrowed
SELECT 
  b.title,
  a.author_name,
  b.genre,
  c.acquisition_date
FROM book_copies c
JOIN books b ON c.book_id = b.book_id
JOIN authors a ON b.author_id = a.author_id
LEFT JOIN loans l ON c.copy_id = l.copy_id
WHERE l.loan_id IS NULL
ORDER BY c.acquisition_date ASC;

-- 4.6 Member Borrowing Activity
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  COUNT(l.loan_id) AS total_loans,
  SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) AS active_loans,
  COALESCE(SUM(CASE WHEN f.paid = FALSE THEN f.fine_amount ELSE 0 END), 0) AS unpaid_fines
FROM members m
LEFT JOIN loans l ON m.member_id = l.member_id
LEFT JOIN fines f ON l.loan_id = f.loan_id
GROUP BY m.member_id
HAVING total_loans > 0
ORDER BY total_loans DESC
LIMIT 10;

-- 4.7 Monthly Loan Statistics
SELECT 
  YEAR(l.loan_date) AS loan_year,
  MONTH(l.loan_date) AS loan_month,
  COUNT(l.loan_id) AS total_loans,
  COUNT(DISTINCT l.member_id) AS unique_borrowers,
  COUNT(DISTINCT c.book_id) AS unique_books
FROM loans l
JOIN book_copies c ON l.copy_id = c.copy_id
GROUP BY YEAR(l.loan_date), MONTH(l.loan_date)
ORDER BY loan_year DESC, loan_month DESC
LIMIT 6;

-- 4.8 Event Registration Summary
SELECT 
  e.event_name,
  e.event_date,
  COUNT(er.registration_id) AS registrations,
  e.max_attendees,
  ROUND((COUNT(er.registration_id) * 100.0 / e.max_attendees), 1) AS capacity_percentage
FROM events e
LEFT JOIN event_registrations er ON e.event_id = er.event_id
WHERE e.event_date > CURDATE()
GROUP BY e.event_id, e.event_name, e.event_date, e.max_attendees
ORDER BY capacity_percentage DESC;
