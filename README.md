# 🎓 College Event Management System – Oracle SQL + PL/SQL Project

This project is a comprehensive database-driven system to manage and streamline college events including event scheduling, budget handling, permissions, and organizer linkage using advanced DBMS features in Oracle.

---

## 📌 Overview

The **College Event Management System** enables administrative control over:
- Organizers and their contact details
- Event creation with time/date validation
- Linking organizers to events with descriptions
- Budget allocation and validation
- Permission scheduling and approval with constraints
- Full modularity using stored procedures and triggers

---

## 💻 Technologies Used

- **Oracle SQL** – Tables, Constraints, Sequences
- **PL/SQL** – Triggers, Procedures, Functions, Packages
- **SQL Developer / Oracle 19c**

---

## 🗃️ Database Schema

### Tables
- `ORGANISER` – Stores organizer details
- `EVENT` – Stores event metadata
- `ORGANISED_BY` – Junction table to link events and organisers
- `BUDGET` – Tracks funding, marketing, and donations
- `PERMISSION_SCHEDULE` – Requests for venue and logistics
- `PERMISSION` – Stores approved permissions

### Sequences
- `organiser_seq`, `event_seq`, `permission_seq`

### Triggers
- Auto-generate IDs like `ORG0001`, `EVT0001`, `PERM0001`
- Budget validation trigger

### PL/SQL Package (`event_management_pkg`)
Contains:
- `add_organiser`, `add_event`
- `link_organiser_event`
- `add_budget`, `request_permission`, `approve_permission`
- `get_budget_status` (returns 'Sufficient' or 'Insufficient')

---

##  How to Run

1. Open **Oracle SQL Developer**
2. Execute all `CREATE TABLE`, `SEQUENCE`, `TRIGGER`, and `PACKAGE` scripts from `DBMS_Code.sql`
3. Run the test execution blocks at the bottom to:
   - Add sample organisers and events
   - Link them
   - Add budgets
   - Request and approve permissions
   - Check budget status

Example procedure call:
```sql
BEGIN
  event_management_pkg.add_event(
    p_event_name => 'Tech Fest',
    p_event_type => 'Competition',
    p_start_date => DATE '2025-09-10',
    p_end_date => DATE '2025-09-12',
    p_starting_time => TO_TIMESTAMP('2025-09-10 10:00:00', 'YYYY-MM-DD HH24:MI:SS'),
    p_ending_time => TO_TIMESTAMP('2025-09-10 12:00:00', 'YYYY-MM-DD HH24:MI:SS')
  );
END;
