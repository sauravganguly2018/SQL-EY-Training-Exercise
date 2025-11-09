-- 8.1 Rank Members by Borrowing Activity
SELECT 
  ROW_NUMBER() OVER (ORDER BY COUNT(l.loan_id) DESC) AS row_num,
  RANK() OVER (ORDER BY COUNT(l.loan_id) DESC) AS rank_no,
  DENSE_RANK() OVER (ORDER BY COUNT(l.loan_id) DESC) AS dense_rank_no,
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  COUNT(l.loan_id) AS total_loans
FROM members m
JOIN loans l ON m.member_id = l.member_id
GROUP BY m.member_id
ORDER BY total_loans DESC;

-- 8.2 Running Total of Fines Collected
SELECT 
  f.payment_date,
  f.fine_amount AS fine_amount,
  SUM(f.fine_amount) OVER (ORDER BY f.payment_date) AS running_total
FROM fines f
WHERE f.paid = TRUE
ORDER BY f.payment_date;

-- 8.3 Rank Books by Genre (Top 3 per Genre)
WITH genre_rank AS (
  SELECT 
    b.genre,
    b.title,
    COUNT(l.loan_id) AS loan_count,
    RANK() OVER (PARTITION BY b.genre ORDER BY COUNT(l.loan_id) DESC) AS genre_rank
  FROM books b
  JOIN book_copies bc ON b.book_id = bc.book_id
  LEFT JOIN loans l ON bc.copy_id = l.copy_id
  GROUP BY b.book_id, b.genre
)
SELECT genre, title, loan_count, genre_rank
FROM genre_rank
WHERE genre_rank <= 3
ORDER BY genre, genre_rank;

-- 8.4 Loan Frequency Comparison
WITH monthly_loans AS (
  SELECT 
    m.member_id,
    CONCAT(m.first_name, ' ', m.last_name) AS member_name,
    DATE_FORMAT(l.loan_date, '%Y-%m') AS loan_month,
    COUNT(l.loan_id) AS monthly_loans
  FROM members m
  JOIN loans l ON m.member_id = l.member_id
  GROUP BY m.member_id, loan_month
)
SELECT 
  member_name,
  loan_month,
  monthly_loans,
  LAG(monthly_loans) OVER (PARTITION BY member_name ORDER BY loan_month) AS prev_month_loans,
  monthly_loans - LAG(monthly_loans) OVER (PARTITION BY member_name ORDER BY loan_month) AS difference
FROM monthly_loans
ORDER BY member_name, loan_month;

-- 8.5 Next Event for Each Member
WITH upcoming_events AS (
  SELECT 
    r.member_id,
    CONCAT(m.first_name, ' ', m.last_name) AS member_name,
    e.event_name,
    e.event_date,
    ROW_NUMBER() OVER (PARTITION BY r.member_id ORDER BY e.event_date) AS rn
  FROM event_registrations r
  JOIN members m ON r.member_id = m.member_id
  JOIN events e ON r.event_id = e.event_id
  WHERE e.event_date >= CURDATE()
)
SELECT member_name, event_name AS next_event, event_date
FROM upcoming_events
WHERE rn = 1
ORDER BY event_date;

-- 8.6 Moving Average of Loans (7-day window)
WITH daily_loans AS (
  SELECT 
    DATE(l.loan_date) AS loan_day,
    COUNT(l.loan_id) AS loans_count
  FROM loans l
  GROUP BY loan_day
)
SELECT 
  loan_day,
  loans_count,
  ROUND(AVG(loans_count) OVER (ORDER BY loan_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_7_days
FROM daily_loans
ORDER BY loan_day DESC
LIMIT 30;

-- 8.7 Percentile Ranking of Fines (Unpaid)
-- 8.7 Percentile Ranking of Fines (Unpaid)
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  f.fine_amount AS fine_amount,
  ROUND(PERCENT_RANK() OVER (ORDER BY f.fine_amount) * 100, 2) AS percentile_rank
FROM fines f
JOIN loans l ON f.loan_id = l.loan_id
JOIN members m ON l.member_id = m.member_id
WHERE f.paid = FALSE
ORDER BY percentile_rank DESC;

-- 8.8 Gap Analysis - Days Between Loans
SELECT 
  CONCAT(m.first_name, ' ', m.last_name) AS member_name,
  l.loan_date,
  LAG(l.loan_date) OVER (PARTITION BY m.member_id ORDER BY l.loan_date) AS prev_loan_date,
  DATEDIFF(l.loan_date, LAG(l.loan_date) OVER (PARTITION BY m.member_id ORDER BY l.loan_date)) AS days_gap
FROM members m
JOIN loans l ON m.member_id = l.member_id
WHERE l.loan_id IS NOT NULL
ORDER BY member_name, l.loan_date;
