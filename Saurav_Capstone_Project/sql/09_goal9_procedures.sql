-- 9.1 CheckoutBook - Procedure to checkout a book for a member
DROP PROCEDURE IF EXISTS CheckoutBook;
DELIMITER //
CREATE PROCEDURE CheckoutBook(
    IN p_member_id INT,
    IN p_copy_id INT,
    OUT p_due_date DATE,
    OUT p_message VARCHAR(200)
)
BEGIN
    DECLARE v_member_status VARCHAR(20);
    DECLARE v_copy_status VARCHAR(20);
    DECLARE v_today DATE;

    SET v_today = CURDATE();

    -- Check member status
    SELECT status INTO v_member_status
    FROM members
    WHERE member_id = p_member_id;

    IF v_member_status IS NULL THEN
        SET p_message = 'Member not found.';
        SET p_due_date = NULL;

    ELSEIF v_member_status <> 'active' THEN
        SET p_message = 'Member not active.';
        SET p_due_date = NULL;

    ELSE
        -- Check book copy status
        SELECT condition_status INTO v_copy_status
        FROM book_copies
        WHERE copy_id = p_copy_id;

        IF v_copy_status IS NULL THEN
            SET p_message = 'Book copy not found.';
            SET p_due_date = NULL;

        ELSEIF v_copy_status <> 'available' THEN
            SET p_message = 'Book copy not available.';
            SET p_due_date = NULL;

        ELSE
            -- Insert loan record and update copy status
            SET p_due_date = DATE_ADD(v_today, INTERVAL 14 DAY);

            INSERT INTO loans (member_id, copy_id, loan_date, due_date, status)
            VALUES (p_member_id, p_copy_id, v_today, p_due_date, 'active');

            UPDATE book_copies 
            SET condition_status = 'checked_out' 
            WHERE copy_id = p_copy_id;

            SET p_message = CONCAT('Book checked out. Due on ', p_due_date);

        END IF;
    END IF;
END //
DELIMITER ;

-- 9.2 ReturnBook - Procedure to return a book and calculate fines
DROP PROCEDURE IF EXISTS ReturnBook;
DELIMITER //
CREATE PROCEDURE ReturnBook(
    IN p_loan_id INT,
    OUT p_fine_amount DECIMAL(10,2),
    OUT p_message VARCHAR(200)
)
BEGIN
    DECLARE v_due_date DATE;
    DECLARE v_copy_id INT;
    DECLARE v_days_late INT;
    DECLARE v_fine_rate DECIMAL(5,2) DEFAULT 0.25;
    SET p_fine_amount = 0.00;

    SELECT due_date, copy_id INTO v_due_date, v_copy_id
    FROM loans
    WHERE loan_id = p_loan_id AND status = 'active';

    IF v_due_date IS NULL THEN
        SET p_message = 'Loan not found or already returned.';
    ELSE
        UPDATE loans 
        SET return_date = CURDATE(), status = 'returned'
        WHERE loan_id = p_loan_id;

        UPDATE book_copies 
        SET condition_status = 'available' 
        WHERE copy_id = v_copy_id;

        SET v_days_late = CalculateFineDays(v_due_date, CURDATE());

        IF v_days_late > 0 THEN
            SET p_fine_amount = v_days_late * v_fine_rate;
            INSERT INTO fines (loan_id, fine_amount, paid)
            VALUES (p_loan_id, p_fine_amount, FALSE);
            SET p_message = CONCAT('Returned late by ', v_days_late, ' days. Fine $', p_fine_amount);
        ELSE
            SET p_message = 'Returned on time. No fine.';
        END IF;
    END IF;
END //
DELIMITER ;

-- 9.3 CalculateFineDays - Function to calculate overdue days
DROP FUNCTION IF EXISTS CalculateFineDays;
DELIMITER //
CREATE FUNCTION CalculateFineDays(
    p_due_date DATE,
    p_return_date DATE
) RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE days_late INT;
    SET days_late = DATEDIFF(p_return_date, p_due_date);
    IF days_late < 0 THEN
        RETURN 0;
    ELSE
        RETURN days_late;
    END IF;
END //
DELIMITER ;

-- 9.4 GenerateMemberReport - Procedure to generate comprehensive member report
DROP PROCEDURE IF EXISTS GenerateMemberReport;
DELIMITER //
CREATE PROCEDURE GenerateMemberReport(
    IN p_member_id INT
)
BEGIN
    -- Member Info
    SELECT first_name, last_name, email, membership_type, status
    FROM members
    WHERE member_id = p_member_id;

    -- Current Loans
    SELECT b.title, l.loan_date, l.due_date
    FROM loans l
    JOIN book_copies bc ON l.copy_id = bc.copy_id
    JOIN books b ON bc.book_id = b.book_id
    WHERE l.member_id = p_member_id AND l.status = 'active';

    -- Unpaid Fines
    SELECT IFNULL(SUM(f.fine_amount),0) AS total_unpaid
    FROM fines f
    JOIN loans l ON f.loan_id = l.loan_id
    WHERE l.member_id = p_member_id AND f.paid = FALSE;

    -- Upcoming Events
    SELECT e.event_name, e.event_date
    FROM event_registrations er
    JOIN events e ON er.event_id = e.event_id
    WHERE er.member_id = p_member_id AND e.event_date >= CURDATE();
END //
DELIMITER ;

-- Test Calls
CALL CheckoutBook(1, 5, @due, @msg);
SELECT @due, @msg;

CALL ReturnBook(1, @fine, @msg);
SELECT @fine, @msg;

SELECT CalculateFineDays('2024-01-01', '2024-01-15') AS days;

CALL GenerateMemberReport(1);
