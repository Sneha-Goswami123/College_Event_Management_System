-- Drop the tables
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE PERMISSION';
    EXECUTE IMMEDIATE 'DROP TABLE PERMISSION_SCHEDULE';
    EXECUTE IMMEDIATE 'DROP TABLE BUDGET';
    EXECUTE IMMEDIATE 'DROP TABLE ORGANISED_BY';
    EXECUTE IMMEDIATE 'DROP TABLE EVENT';
    EXECUTE IMMEDIATE 'DROP TABLE ORGANISER';
EXCEPTION
    WHEN OTHERS THEN
        NULL; 
END;
/

-- Create sequences for auto-incrementing IDs
CREATE SEQUENCE organiser_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE event_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE permission_seq START WITH 1 INCREMENT BY 1;

-- ORGANISER Table
CREATE TABLE ORGANISER (
    id VARCHAR2(10) PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    contact VARCHAR2(15) UNIQUE NOT NULL,
    faculty_representative VARCHAR2(50),
    CONSTRAINT chk_contact CHECK (REGEXP_LIKE(contact, '^[0-9]{10,15}$'))
);

-- EVENT Table
CREATE TABLE EVENT (
    id VARCHAR2(10) PRIMARY KEY,
    event_name VARCHAR2(100) NOT NULL,
    event_type VARCHAR2(25),
    start_date DATE,
    end_date DATE,
    starting_time TIMESTAMP,
    ending_time TIMESTAMP,
    CONSTRAINT chk_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_times CHECK (ending_time >= starting_time)
);

-- ORGANISED_BY Table
CREATE TABLE ORGANISED_BY (
    o_id VARCHAR2(10) NOT NULL,
    e_id VARCHAR2(10) NOT NULL,
    event_description VARCHAR2(1000),
    PRIMARY KEY (o_id, e_id),
    FOREIGN KEY (o_id) REFERENCES ORGANISER(id) ON DELETE CASCADE,
    FOREIGN KEY (e_id) REFERENCES EVENT(id) ON DELETE CASCADE
);

-- BUDGET Table
CREATE TABLE BUDGET (
    o_id VARCHAR2(10) NOT NULL,
    e_id VARCHAR2(10) NOT NULL,
    left_available NUMBER(10,2) NOT NULL,
    needed NUMBER(10,2),
    marketing_fund NUMBER(10,2),
    donation_college NUMBER(10,2),
    PRIMARY KEY (o_id, e_id),
    FOREIGN KEY (o_id) REFERENCES ORGANISER(id) ON DELETE CASCADE,
    FOREIGN KEY (e_id) REFERENCES EVENT(id) ON DELETE CASCADE,
    CONSTRAINT chk_budget_positive CHECK (left_available >= 0 AND needed >= 0 AND marketing_fund >= 0 AND donation_college >= 0)
);

-- PERMISSION_SCHEDULE Table
CREATE TABLE PERMISSION_SCHEDULE (
    venue VARCHAR2(50) NOT NULL,
    starting_time TIMESTAMP NOT NULL,
    ending_time TIMESTAMP NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    headcount NUMBER,
    representative_name VARCHAR2(50),
    representative_id VARCHAR2(25) NOT NULL,
    o_id VARCHAR2(10),
    PRIMARY KEY (venue, starting_time, ending_time, start_date, end_date),
    FOREIGN KEY (o_id) REFERENCES ORGANISER(id) ON DELETE SET NULL,
    CONSTRAINT chk_perm_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_perm_times CHECK (ending_time >= starting_time),
    CONSTRAINT chk_headcount CHECK (headcount >= 0)
);

-- PERMISSION Table
CREATE TABLE PERMISSION (
    pid VARCHAR2(10) PRIMARY KEY,
    venue VARCHAR2(50) NOT NULL,
    starting_time TIMESTAMP NOT NULL,
    ending_time TIMESTAMP NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    FOREIGN KEY (venue, starting_time, ending_time, start_date, end_date)
        REFERENCES PERMISSION_SCHEDULE(venue, starting_time, ending_time, start_date, end_date)
        ON DELETE CASCADE
);

-- Triggers
CREATE OR REPLACE TRIGGER organiser_id_trg
BEFORE INSERT ON ORGANISER
FOR EACH ROW
BEGIN
    :NEW.id := 'ORG' || TO_CHAR(organiser_seq.NEXTVAL, 'FM0000');
END;
/

CREATE OR REPLACE TRIGGER event_id_trg
BEFORE INSERT ON EVENT
FOR EACH ROW
BEGIN
    :NEW.id := 'EVT' || TO_CHAR(event_seq.NEXTVAL, 'FM0000');
END;
/

CREATE OR REPLACE TRIGGER permission_id_trg
BEFORE INSERT ON PERMISSION
FOR EACH ROW
BEGIN
    :NEW.pid := 'PERM' || TO_CHAR(permission_seq.NEXTVAL, 'FM0000');
END;
/

CREATE OR REPLACE TRIGGER budget_update_trg
BEFORE UPDATE ON BUDGET
FOR EACH ROW
BEGIN
    IF :NEW.left_available < 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Budget left cannot be negative.');
    END IF;
END;
/

-- PL/SQL Package Specification
CREATE OR REPLACE PACKAGE event_management_pkg AS
    PROCEDURE add_organiser(p_name IN VARCHAR2, p_contact IN VARCHAR2, p_faculty_rep IN VARCHAR2);
    PROCEDURE add_event(p_event_name IN VARCHAR2, p_event_type IN VARCHAR2, p_start_date IN DATE, p_end_date IN DATE, p_starting_time IN TIMESTAMP, p_ending_time IN TIMESTAMP);
    PROCEDURE link_organiser_event(p_o_id IN VARCHAR2, p_e_id IN VARCHAR2, p_description IN VARCHAR2);
    PROCEDURE add_budget(p_o_id IN VARCHAR2, p_e_id IN VARCHAR2, p_left_available IN NUMBER, p_needed IN NUMBER, p_marketing_fund IN NUMBER, p_donation_college IN NUMBER);
    PROCEDURE request_permission(p_venue IN VARCHAR2, p_starting_time IN TIMESTAMP, p_ending_time IN TIMESTAMP, p_start_date IN DATE, p_end_date IN DATE, p_headcount IN NUMBER, p_rep_name IN VARCHAR2, p_rep_id IN VARCHAR2, p_o_id IN VARCHAR2);
    PROCEDURE approve_permission(p_venue IN VARCHAR2, p_starting_time IN TIMESTAMP, p_ending_time IN TIMESTAMP, p_start_date IN DATE, p_end_date IN DATE);
    FUNCTION get_budget_status(p_e_id IN VARCHAR2) RETURN VARCHAR2;
END event_management_pkg;
/

-- PL/SQL Package Body
CREATE OR REPLACE PACKAGE BODY event_management_pkg AS
    PROCEDURE add_organiser(p_name IN VARCHAR2, p_contact IN VARCHAR2, p_faculty_rep IN VARCHAR2) AS
    BEGIN
        INSERT INTO ORGANISER (name, contact, faculty_representative)
        VALUES (p_name, p_contact, p_faculty_rep);
        COMMIT;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20002, 'Contact number already exists.');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20003, 'Error adding organiser: ' || SQLERRM);
    END;

    PROCEDURE add_event(p_event_name IN VARCHAR2, p_event_type IN VARCHAR2, p_start_date IN DATE, p_end_date IN DATE, p_starting_time IN TIMESTAMP, p_ending_time IN TIMESTAMP) AS
    BEGIN
        INSERT INTO EVENT (event_name, event_type, start_date, end_date, starting_time, ending_time)
        VALUES (p_event_name, p_event_type, p_start_date, p_end_date, p_starting_time, p_ending_time);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20004, 'Error adding event: ' || SQLERRM);
    END;

  PROCEDURE link_organiser_event(p_o_id IN VARCHAR2, p_e_id IN VARCHAR2, p_description IN VARCHAR2) AS
BEGIN
    INSERT INTO ORGANISED_BY (o_id, e_id, event_description)
    VALUES (p_o_id, p_e_id, p_description);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20005, 'Error linking organiser and event: ' || SQLERRM);
END;



    PROCEDURE add_budget(p_o_id IN VARCHAR2, p_e_id IN VARCHAR2, p_left_available IN NUMBER, p_needed IN NUMBER, p_marketing_fund IN NUMBER, p_donation_college IN NUMBER) AS
    BEGIN
        INSERT INTO BUDGET (o_id, e_id, left_available, needed, marketing_fund, donation_college)
        VALUES (p_o_id, p_e_id, p_left_available, p_needed, p_marketing_fund, p_donation_college);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20006, 'Error adding budget: ' || SQLERRM);
    END;

    PROCEDURE request_permission(p_venue IN VARCHAR2, p_starting_time IN TIMESTAMP, p_ending_time IN TIMESTAMP, p_start_date IN DATE, p_end_date IN DATE, p_headcount IN NUMBER, p_rep_name IN VARCHAR2, p_rep_id IN VARCHAR2, p_o_id IN VARCHAR2) AS
    BEGIN
        INSERT INTO PERMISSION_SCHEDULE (venue, starting_time, ending_time, start_date, end_date, headcount, representative_name, representative_id, o_id)
        VALUES (p_venue, p_starting_time, p_ending_time, p_start_date, p_end_date, p_headcount, p_rep_name, p_rep_id, p_o_id);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20007, 'Error requesting permission: ' || SQLERRM);
    END;

    PROCEDURE approve_permission(p_venue IN VARCHAR2, p_starting_time IN TIMESTAMP, p_ending_time IN TIMESTAMP, p_start_date IN DATE, p_end_date IN DATE) AS
    BEGIN
        INSERT INTO PERMISSION (venue, starting_time, ending_time, start_date, end_date)
        VALUES (p_venue, p_starting_time, p_ending_time, p_start_date, p_end_date);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20008, 'Error approving permission: ' || SQLERRM);
    END;

    FUNCTION get_budget_status(p_e_id IN VARCHAR2) RETURN VARCHAR2 AS
        v_left NUMBER(10,2);
        v_needed NUMBER(10,2);
    BEGIN
        SELECT left_available, needed INTO v_left, v_needed
        FROM BUDGET
        WHERE e_id = p_e_id;

        IF v_left >= v_needed THEN
            RETURN 'Sufficient';
        ELSE
            RETURN 'Insufficient';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'Budget not found';
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20009, 'Error retrieving budget status: ' || SQLERRM);
    END;
END event_management_pkg;
/
SHOW ERRORS PACKAGE BODY event_management_pkg;

-- Enable DBMS_OUTPUT
SET SERVEROUTPUT ON;

-- Test Execution Block 1: Add Organiser
BEGIN
  event_management_pkg.add_organiser('Charlie Das', '9988776655', 'Dr. Kumar');
END;
/




-- Test Execution Block 2: Add Event
BEGIN
  event_management_pkg.add_event(
    p_event_name => 'Tech Fest',
    p_event_type => 'Competition',
    p_start_date => DATE '2025-09-10',
    p_end_date => DATE '2025-09-12',
    p_starting_time => TO_TIMESTAMP('2025-09-10 10:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time => TO_TIMESTAMP('2025-09-10 12:00:00', 'YYYY-MM-DD HH24:MI:SS')
  );

  event_management_pkg.add_event(
    p_event_name => 'Workshop on AI',
    p_event_type => 'Workshop',
    p_start_date => DATE '2025-09-15',
    p_end_date => DATE '2025-09-15',
    p_starting_time => TO_TIMESTAMP('2025-09-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time => TO_TIMESTAMP('2025-09-15 16:30:00', 'YYYY-MM-DD HH24:MI:SS')
  );
END;
/

SELECT id, name FROM organiser;
SELECT id, event_name FROM event;

SELECT id, name FROM organiser WHERE id IN ('ORG0001', 'ORG0002');
SELECT id, event_name FROM event WHERE id IN ('EVT0061', 'EVT0062');


-- Test Execution Block 3: Link Organiser and Event
BEGIN
  event_management_pkg.link_organiser_event(
    p_o_id => 'ORG0001',  -- make sure this organiser exists in your ORGANISER table
    p_e_id => 'EVT0061',  -- make sure this event exists in your EVENT table
    p_description => 'Main Coordinator for Tech Fest'
  );

  event_management_pkg.link_organiser_event(
    p_o_id => 'ORG0002',
    p_e_id => 'EVT0062',
    p_description => 'Lead Organiser for AI Workshop'
  );
END;
/


-- 1. Add Two Organisers
BEGIN
  event_management_pkg.add_organiser(
    p_name => 'Alice Singh',
    p_contact => '9876543210',
    p_faculty_rep => 'Dr. Patel'
  );
  DBMS_OUTPUT.PUT_LINE('Organiser Alice added.');

  event_management_pkg.add_organiser(
    p_name => 'Bob Mehta',
    p_contact => '9123456662',
    p_faculty_rep => 'Prof. Iyer'
  );
  DBMS_OUTPUT.PUT_LINE('Organiser Bob added.');
END;
/
-- 2. Add Two Events

BEGIN
  event_management_pkg.add_event(
    p_event_name => 'Tech Fest',
    p_event_type => 'Competition',
    p_start_date => DATE '2025-09-10',
    p_end_date   => DATE '2025-09-12',
    p_starting_time => TO_TIMESTAMP('2025-09-10 10:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time   => TO_TIMESTAMP('2025-09-10 12:00:00', 'YYYY-MM-DD HH24:MI:SS')
  );
  DBMS_OUTPUT.PUT_LINE('Event Tech Fest added.');

  event_management_pkg.add_event(
    p_event_name => 'Workshop on AI',
    p_event_type => 'Workshop',
    p_start_date => DATE '2025-09-15',
    p_end_date   => DATE '2025-09-15',
    p_starting_time => TO_TIMESTAMP('2025-09-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time   => TO_TIMESTAMP('2025-09-15 16:30:00', 'YYYY-MM-DD HH24:MI:SS')
  );
  DBMS_OUTPUT.PUT_LINE('Event Workshop added.');
END;

SELECT id, name FROM organiser WHERE id IN ('ORG0041', 'ORG0042');
SELECT id, event_name FROM event WHERE id IN ('EVT0061', 'EVT0062');

-- 1. Insert Organisers with IDs
INSERT INTO organiser (id, name, contact, faculty_representative)
VALUES ('ORG0001', 'Alice Singh', '9876543210', 'Dr. Patel');

INSERT INTO organiser (id, name, contact, faculty_representative)
VALUES ('ORG0002', 'Bob Mehta', '9123456662', 'Prof. Iyer');

-- 2. Insert Events with IDs
INSERT INTO event (id, event_name, event_type, start_date, end_date, starting_time, ending_time)
VALUES ('EVT0061', 'Tech Fest', 'Competition', TO_DATE('2025-09-10', 'YYYY-MM-DD'), TO_DATE('2025-09-12', 'YYYY-MM-DD'),
        TO_TIMESTAMP('2025-09-10 10:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('2025-09-10 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));

INSERT INTO event (id, event_name, event_type, start_date, end_date, starting_time, ending_time)
VALUES ('EVT0062', 'Workshop on AI', 'Workshop', TO_DATE('2025-09-15', 'YYYY-MM-DD'), TO_DATE('2025-09-15', 'YYYY-MM-DD'),
        TO_TIMESTAMP('2025-09-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_TIMESTAMP('2025-09-15 16:30:00', 'YYYY-MM-DD HH24:MI:SS'));

COMMIT;

-- 3. Link Organisers with Events using the package procedure
BEGIN
  event_management_pkg.link_organiser_event(
    p_o_id => 'ORG0041',
    p_e_id => 'EVT0061',
    p_description => 'Main Coordinator for Tech Fest'
  );

  event_management_pkg.link_organiser_event(
    p_o_id => 'ORG0042',
    p_e_id => 'EVT0062',
    p_description => 'Lead Organiser for AI Workshop'
  );
END;
/

-- 4. Add Budget for Events
BEGIN
  event_management_pkg.add_budget(
    p_o_id => 'ORG0041',
    p_e_id => 'EVT0061',
    p_left_available => 10000,
    p_needed => 8000,
    p_marketing_fund => 2000,
    p_donation_college => 3000
  );

  event_management_pkg.add_budget(
    p_o_id => 'ORG0042',
    p_e_id => 'EVT0062',
    p_left_available => 5000,
    p_needed => 7000,
    p_marketing_fund => 1500,
    p_donation_college => 2000
  );
END;
/

-- 5. Request Permissions for Both Events
BEGIN
  event_management_pkg.request_permission(
    p_venue => 'Auditorium',
    p_starting_time => TO_TIMESTAMP('2025-09-10 10:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time   => TO_TIMESTAMP('2025-09-10 12:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_start_date => DATE '2025-09-10',
    p_end_date   => DATE '2025-09-12',
    p_headcount => 300,
    p_rep_name => 'Alice Singh',
    p_rep_id => 'REP001',
    p_o_id => 'ORG0041'
  );

  event_management_pkg.request_permission(
    p_venue => 'Lab 101',
    p_starting_time => TO_TIMESTAMP('2025-09-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time   => TO_TIMESTAMP('2025-09-15 16:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_start_date => DATE '2025-09-15',
    p_end_date   => DATE '2025-09-15',
    p_headcount => 80,
    p_rep_name => 'Bob Mehta',
    p_rep_id => 'REP002',
    p_o_id => 'ORG0042'
  );
END;
/

-- 6. Approve the Permissions
BEGIN
  event_management_pkg.approve_permission(
    p_venue => 'Auditorium',
    p_starting_time => TO_TIMESTAMP('2025-09-10 10:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time   => TO_TIMESTAMP('2025-09-10 12:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_start_date => DATE '2025-09-10',
    p_end_date   => DATE '2025-09-12'
  );

  event_management_pkg.approve_permission(
    p_venue => 'Lab 101',
    p_starting_time => TO_TIMESTAMP('2025-09-15 14:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time   => TO_TIMESTAMP('2025-09-15 16:30:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_start_date => DATE '2025-09-15',
    p_end_date   => DATE '2025-09-15'
  );
END;
/

-- 7. Check Budget Status
DECLARE
  result VARCHAR2(100);
BEGIN
  result := event_management_pkg.get_budget_status('EVT0001');
  DBMS_OUTPUT.PUT_LINE('Tech Fest Budget Status: ' || result);

  result := event_management_pkg.get_budget_status('EVT0002');
  DBMS_OUTPUT.PUT_LINE('AI Workshop Budget Status: ' || result);
END;
/

select * from organiser;
select * from event;