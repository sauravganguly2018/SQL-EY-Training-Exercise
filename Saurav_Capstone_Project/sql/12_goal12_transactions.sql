-- 12.1 Safe Book Checkout (as a procedure)
DELIMITER //
CREATE PROCEDURE SafeCheckout(IN p_member_id INT, IN p_book_id INT)
BEGIN
    DECLARE available_copy INT;

    START TRANSACTION;

    -- Step 1: Find available copy
    SELECT copy_id INTO available_copy
    FROM book_copies bc
    WHERE book_id = p_book_id
      AND copy_id NOT IN (SELECT copy_id FROM loans WHERE status = 'active')
    LIMIT 1;

    -- If no copy available, rollback
    IF available_copy IS NULL THEN
        ROLLBACK;
        SELECT 'No available copy to checkout' AS message;
    ELSE
        -- Step 2: Create loan
        INSERT INTO loans (member_id, copy_id, loan_date, due_date, status)
        VALUES (p_member_id, available_copy, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 14 DAY), 'active');

        -- Step 3: Log the action
        INSERT INTO audit_log (table_name, action, record_id, description)
        VALUES ('loans', 'INSERT', LAST_INSERT_ID(), 'Book checked out');

        COMMIT;
        SELECT 'Checkout successful' AS message;
    END IF;
END //
DELIMITER ;

-- 12.2 Process Fine Payment (as a procedure)
DELIMITER //
CREATE PROCEDURE PayFine(IN p_fine_id INT)
BEGIN
    START TRANSACTION;

    -- Step 1: Mark fine as paid
    UPDATE fines
    SET paid = TRUE, payment_date = CURDATE()
    WHERE fine_id = p_fine_id;

    -- Step 2: Log payment
    INSERT INTO audit_log (table_name, action, record_id, description)
    VALUES ('fines', 'UPDATE', p_fine_id, CONCAT('Fine paid: $', (SELECT fine_amount FROM fines WHERE fine_id = p_fine_id)));

    -- Step 3: Reactivate member if no other unpaid fines
    UPDATE members
    SET status = 'active'
    WHERE member_id = (
      SELECT l.member_id
      FROM fines f
      JOIN loans l ON f.loan_id = l.loan_id
      WHERE f.fine_id = p_fine_id
    )
    AND status = 'suspended'
    AND NOT EXISTS (
      SELECT 1 FROM fines f2
      JOIN loans l2 ON f2.loan_id = l2.loan_id
      WHERE l2.member_id = members.member_id
        AND f2.paid = FALSE
        AND f2.fine_id != p_fine_id
    );

    COMMIT;
END //
DELIMITER ;

-- 12.3 Rollback Example (Error Handling)
DELIMITER //
CREATE PROCEDURE CheckoutWithLimit(IN p_member_id INT, IN p_copy_id INT)
BEGIN
    DECLARE active_count INT;

    START TRANSACTION;

    -- Step 1: Attempt to checkout
    INSERT INTO loans (member_id, copy_id, loan_date, due_date, status)
    VALUES (p_member_id, p_copy_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 14 DAY), 'active');

    -- Step 2: Check active loans count
    SELECT COUNT(*) INTO active_count FROM loans
    WHERE member_id = p_member_id AND status = 'active';

    IF active_count > 5 THEN
        ROLLBACK;
        SELECT 'Transaction rolled back: Member has too many active loans' AS message;
    ELSE
        COMMIT;
        SELECT 'Transaction committed successfully' AS message;
    END IF;
END //
DELIMITER ;

-- 12.4 Batch Book Return (as a procedure)
DELIMITER //
CREATE PROCEDURE BatchReturn(IN p_member_id INT)
BEGIN
    START TRANSACTION;

    -- Step 1: Return all active loans
    UPDATE loans
    SET status = 'returned', return_date = CURDATE()
    WHERE member_id = p_member_id AND status = 'active';

    -- Step 2: Calculate fines for overdue
    INSERT INTO fines (loan_id, fine_amount, fine_reason, paid)
    SELECT loan_id,
           GREATEST(0, DATEDIFF(CURDATE(), due_date)) * 0.25,
           'overdue',
           FALSE
    FROM loans
    WHERE member_id = p_member_id
      AND status = 'returned'
      AND return_date > due_date
      AND loan_id NOT IN (SELECT loan_id FROM fines);

    -- Step 3: Log batch return
    INSERT INTO audit_log (table_name, action, record_id, description)
    VALUES ('loans', 'UPDATE', p_member_id, CONCAT('Batch return for member ', p_member_id, ': ', ROW_COUNT(), ' books'));

    COMMIT;
END //
DELIMITER ;

-- 12.5 Test Transactions (Commit and Rollback)
-- Test successful commit
START TRANSACTION;
INSERT INTO members (first_name, last_name, email, membership_type)
VALUES ('Test', 'User', 'test@example.com', 'standard');
SELECT * FROM members WHERE email = 'test@example.com';
COMMIT;

-- Test rollback
START TRANSACTION;
INSERT INTO members (first_name, last_name, email, membership_type)
VALUES ('Rollback', 'Test', 'rollback@example.com', 'standard');
SELECT * FROM members WHERE email = 'rollback@example.com';
ROLLBACK;
SELECT * FROM members WHERE email = 'rollback@example.com';
