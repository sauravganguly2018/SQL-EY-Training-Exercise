-- 10.1 Audit Log for Member Changes
DROP TRIGGER IF EXISTS after_member_update;
DELIMITER //
CREATE TRIGGER after_member_update
AFTER UPDATE ON members
FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, action, record_id, description)
  VALUES (
    'members',
    'UPDATE',
    NEW.member_id,
    CONCAT('Member ', OLD.first_name, ' ', OLD.last_name, 
           ' updated. Status: ', OLD.status, ' -> ', NEW.status)
  );
END //
DELIMITER ;

-- 10.2 Prevent Loan if Member Suspended
DROP TRIGGER IF EXISTS before_loan_insert;
DELIMITER //
CREATE TRIGGER before_loan_insert
BEFORE INSERT ON loans
FOR EACH ROW
BEGIN
  DECLARE member_status VARCHAR(20);
  
  SELECT status INTO member_status
  FROM members
  WHERE member_id = NEW.member_id;
  
  IF member_status != 'active' THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Cannot create loan: Member is not active';
  END IF;
END //
DELIMITER ;

-- 10.3 Auto-Calculate Due Date
DROP TRIGGER IF EXISTS before_loan_insert_due_date;
DELIMITER //
CREATE TRIGGER before_loan_insert_due_date
BEFORE INSERT ON loans
FOR EACH ROW
BEGIN
  IF NEW.due_date IS NULL THEN
    SET NEW.due_date = DATE_ADD(NEW.loan_date, INTERVAL 14 DAY);
  END IF;
END //
DELIMITER ;

-- 10.4 Auto-Create Fine for Overdue Returns
DROP TRIGGER IF EXISTS after_loan_return;
DELIMITER //
CREATE TRIGGER after_loan_return
AFTER UPDATE ON loans
FOR EACH ROW
BEGIN
  DECLARE days_late INT;
  DECLARE fine_amt DECIMAL(10,2);
  
  IF NEW.status = 'returned' AND OLD.status = 'active' THEN
    SET days_late = DATEDIFF(NEW.return_date, NEW.due_date);
    
    IF days_late > 0 THEN
      SET fine_amt = days_late * 0.25;
      INSERT INTO fines (loan_id, fine_amount, fine_reason, paid)
      VALUES (NEW.loan_id, fine_amt, 'overdue', FALSE);
    END IF;
  END IF;
END //
DELIMITER ;

-- 10.5 Prevent Deleting Books with Active Loans
DROP TRIGGER IF EXISTS before_book_delete;
DELIMITER //
CREATE TRIGGER before_book_delete
BEFORE DELETE ON books
FOR EACH ROW
BEGIN
  DECLARE active_loan_count INT;
  
  SELECT COUNT(*) INTO active_loan_count
  FROM loans l
  JOIN book_copies bc ON l.copy_id = bc.copy_id
  WHERE bc.book_id = OLD.book_id AND l.status = 'active';
  
  IF active_loan_count > 0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Cannot delete book: Active loans exist';
  END IF;
END //
DELIMITER ;
