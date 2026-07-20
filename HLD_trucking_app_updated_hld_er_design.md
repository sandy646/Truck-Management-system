# Trucking Driver Management App - Updated HLD and ER Design

## Scope

This document captures the current overall application design based on the functional requirements finalized so far.

## Functional Requirements Covered

```text
1. Trucking owner uploads load document.
2. Backend extracts data using PDF Processor.
3. Owner reviews/approves extracted load data.
4. Backend creates final load record only after approval.
5. Owner assigns approved load to driver / owner-operator.
6. Driver receives SMS notification on load assignment.
```

---

## 1. Updated Overall HLD

```mermaid
flowchart LR
    Owner[Trucking Owner / Company Owner]
    Driver[Driver / Owner Operator]

    Web[Web App / Client UI]
    Backend[Backend App / API Server]

    Storage[File Storage<br/>S3 / Local / GCS]
    PDF[PDF Processor<br/>OCR + Data Extraction]
    DB[(Database)]
    SMS[SMS Service<br/>Twilio / AWS SNS / Provider]

    Owner -->|Upload load PDF| Web
    Owner -->|Review and approve extracted load| Web
    Owner -->|Assign load to driver| Web

    Driver -->|Receives SMS notification| SMS

    Web -->|API requests| Backend

    Backend -->|Store uploaded PDF| Storage
    Storage -->|file_url| Backend

    Backend -->|Send file_url for extraction| PDF
    PDF -->|Return extracted load data| Backend

    Backend -->|Save documents, loads, assignments, notifications| DB
    Backend -->|Read load/driver/company data| DB

    Backend -->|Send SMS on load assignment| SMS
    SMS -->|Provider response| Backend

    Backend -->|Update SMS delivery status| DB
    Backend -->|Response| Web
```

---

## 2. Component Responsibilities

### Client / Web App

Used by:

```text
Trucking Owner
Driver / Owner Operator
```

Owner can:

```text
Upload load PDF
Review extracted load data
Approve load data
Assign load to driver
See assignment/SMS status
```

Driver can:

```text
Receive SMS notification
Later open app and view assigned loads
```

---

### Backend App

Main business logic layer.

Responsibilities:

```text
Authenticate users
Validate owner permissions
Handle load PDF upload
Store document metadata
Call PDF Processor
Store extracted data
Wait for owner approval
Create final load record
Assign load to driver
Create notification record
Call SMS Service
Update SMS delivery status
```

---

### File Storage

Stores uploaded PDFs.

Examples:

```text
AWS S3
Google Cloud Storage
Firebase Storage
Local storage for MVP
```

DB stores only:

```text
file_url
file_name
document metadata
```

---

### PDF Processor

Extracts load data from uploaded documents.

Extracted fields:

```text
load_number
broker_name
pickup_location
dropoff_location
pickup_date
delivery_date
gross_revenue
```

Important rule:

```text
PDF Processor output is not final business data.
Owner approval is required before creating load.
```

---

### Database

Stores:

```text
companies
users
drivers
documents
loads
load_assignments
notifications
expenses
profit_summary
```

Current requirements mainly use:

```text
companies
users
drivers
documents
loads
load_assignments
notifications
```

---

### SMS Service

Sends SMS to driver when load is assigned.

Examples:

```text
Twilio
AWS SNS
Any SMS provider
```

Backend stores SMS result in `notifications`.

---

## 3. Overall Functional Flow

### Flow 1: Owner Uploads Load Document

```text
Owner uploads PDF
→ Backend stores file in storage
→ Backend creates documents row
→ Backend sends file to PDF Processor
→ PDF Processor extracts data
→ Backend stores extracted_data in documents
→ document status = PENDING_OWNER_REVIEW
→ Owner reviews extracted data
```

---

### Flow 2: Owner Approves Load

```text
Owner edits/reviews extracted data
→ Owner clicks approve
→ Backend validates approved data
→ Backend creates loads row
→ Backend updates documents row with approved_data and load_id
→ document status = APPROVED
→ load status = CREATED
```

---

### Flow 3: Owner Assigns Load to Driver

```text
Owner selects CREATED load
→ Owner selects ACTIVE driver
→ Owner enters payout type/details
→ Backend validates load and driver
→ Backend creates load_assignments row
→ Backend updates load status = ASSIGNED
```

---

### Flow 4: Driver Gets SMS Notification

```text
After assignment created
→ Backend creates notifications row with PENDING status
→ Backend calls SMS Service
→ SMS Service sends SMS
→ Backend updates notification status = SENT or FAILED
```

---

## 4. Updated Overall Sequence Diagram

```mermaid
sequenceDiagram
    actor Owner as Trucking Owner
    participant Web as Web App
    participant Backend as Backend App
    participant Storage as File Storage
    participant PDF as PDF Processor
    participant DB as Database
    participant SMS as SMS Service
    actor Driver as Driver / Owner Operator

    Owner->>Web: Upload load PDF
    Web->>Backend: POST /load-documents/upload

    Backend->>Storage: Store PDF
    Storage-->>Backend: file_url

    Backend->>DB: Insert document with PROCESSING status
    DB-->>Backend: document_id

    Backend->>PDF: Extract load data from file_url
    PDF-->>Backend: extracted load data

    Backend->>DB: Update document with extracted_data + PENDING_OWNER_REVIEW
    Backend-->>Web: Return extracted data
    Web-->>Owner: Show editable review screen

    Owner->>Web: Approve reviewed load data
    Web->>Backend: POST /load-documents/{documentId}/approve

    Backend->>DB: Insert load using approved_data
    DB-->>Backend: load_id

    Backend->>DB: Update document with load_id + APPROVED
    Backend-->>Web: Load created
    Web-->>Owner: Show load status CREATED

    Owner->>Web: Assign load to driver
    Web->>Backend: POST /loads/{loadId}/assign

    Backend->>DB: Validate owner, load, driver
    DB-->>Backend: Validation data

    Backend->>DB: Insert load_assignments row
    DB-->>Backend: assignment_id

    Backend->>DB: Update load status = ASSIGNED

    Backend->>DB: Insert notification with PENDING status
    DB-->>Backend: notification_id

    Backend->>SMS: Send SMS to driver phone
    SMS-->>Backend: SMS provider response

    alt SMS sent successfully
        Backend->>DB: Update notification status = SENT
        Backend-->>Web: Assignment success + SMS sent
    else SMS failed
        Backend->>DB: Update notification status = FAILED
        Backend-->>Web: Assignment success + SMS failed warning
    end

    SMS-->>Driver: SMS load assignment notification
```

---

## 5. Updated Overall ER Diagram

```mermaid
erDiagram

    COMPANIES ||--o{ USERS : has
    COMPANIES ||--o{ DRIVERS : owns
    COMPANIES ||--o{ LOADS : manages
    COMPANIES ||--o{ DOCUMENTS : owns
    COMPANIES ||--o{ EXPENSES : owns
    COMPANIES ||--o{ NOTIFICATIONS : owns

    USERS ||--o| DRIVERS : may_have_driver_profile
    USERS ||--o{ DOCUMENTS : uploads
    USERS ||--o{ DOCUMENTS : approves
    USERS ||--o{ LOAD_ASSIGNMENTS : assigns
    USERS ||--o{ EXPENSES : submits
    USERS ||--o{ NOTIFICATIONS : receives

    DRIVERS ||--o{ LOAD_ASSIGNMENTS : assigned_to
    DRIVERS ||--o{ EXPENSES : creates

    LOADS ||--o{ LOAD_ASSIGNMENTS : has
    LOADS ||--o{ EXPENSES : has
    LOADS ||--o{ DOCUMENTS : linked_documents
    LOADS ||--o{ NOTIFICATIONS : related_notifications
    LOADS ||--o| PROFIT_SUMMARY : has_profit_summary

    LOAD_ASSIGNMENTS ||--o{ NOTIFICATIONS : triggers

    EXPENSES ||--o{ DOCUMENTS : linked_receipts

    COMPANIES {
        bigint id PK
        varchar name
        varchar dot_number
        varchar mc_number
        timestamp created_at
        timestamp updated_at
    }

    USERS {
        bigint id PK
        bigint company_id FK
        varchar name
        varchar email
        varchar phone
        varchar role
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    DRIVERS {
        bigint id PK
        bigint company_id FK
        bigint user_id FK
        varchar driver_type
        varchar license_number
        varchar phone
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    LOADS {
        bigint id PK
        bigint company_id FK
        varchar load_number
        varchar broker_name
        varchar pickup_location
        varchar dropoff_location
        date pickup_date
        date delivery_date
        decimal gross_revenue
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    LOAD_ASSIGNMENTS {
        bigint id PK
        bigint load_id FK
        bigint driver_id FK
        bigint assigned_by_user_id FK
        varchar payout_type
        decimal driver_pay_amount
        decimal driver_pay_percentage
        varchar assignment_status
        text notes
        timestamp assigned_at
        timestamp completed_at
    }

    DOCUMENTS {
        bigint id PK
        bigint company_id FK
        bigint uploaded_by_user_id FK
        bigint approved_by_user_id FK
        bigint load_id FK
        bigint expense_id FK
        varchar document_type
        varchar file_name
        varchar file_url
        varchar processing_status
        json extracted_data
        json approved_data
        timestamp uploaded_at
        timestamp processed_at
        timestamp approved_at
    }

    NOTIFICATIONS {
        bigint id PK
        bigint company_id FK
        bigint recipient_user_id FK
        varchar recipient_phone
        varchar notification_type
        varchar title
        text message
        bigint related_load_id FK
        bigint related_assignment_id FK
        varchar delivery_channel
        varchar delivery_status
        varchar provider_message_id
        text failure_reason
        varchar read_status
        timestamp created_at
        timestamp sent_at
        timestamp failed_at
        timestamp read_at
    }

    EXPENSES {
        bigint id PK
        bigint company_id FK
        bigint load_id FK
        bigint driver_id FK
        bigint submitted_by_user_id FK
        varchar expense_type
        varchar vendor_name
        decimal amount
        date expense_date
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    PROFIT_SUMMARY {
        bigint id PK
        bigint load_id FK
        decimal gross_revenue
        decimal total_expenses
        decimal driver_pay
        decimal net_profit
        decimal company_margin
        timestamp calculated_at
    }
```

---

## 6. Current DB Schema Summary

### Core Tables Right Now

```text
companies
users
drivers
documents
loads
load_assignments
notifications
```

### Future/Profit Related Tables Already Planned

```text
expenses
profit_summary
```

Keep `expenses` and `profit_summary` in the overall ER diagram because net profit is part of the product idea, but these will become more important when discussing:

```text
Driver uploads expense receipts
Owner assigns profit margin / payout
System calculates profit
```

---

## 7. Current Status Values

### `documents.processing_status`

```text
PENDING
PROCESSING
PENDING_OWNER_REVIEW
APPROVED
REJECTED
FAILED
```

### `loads.status`

```text
CREATED
ASSIGNED
IN_PROGRESS
DELIVERED
COMPLETED
CANCELLED
```

### `load_assignments.assignment_status`

```text
ASSIGNED
CANCELLED
COMPLETED
```

Future:

```text
ACCEPTED
REJECTED
IN_PROGRESS
```

### `notifications.delivery_status`

```text
PENDING
SENT
FAILED
```

### `notifications.delivery_channel`

```text
SMS
IN_APP
EMAIL
PUSH
```

For current requirement:

```text
SMS
```

---

## 8. Important Current Design Rules

```text
1. PDF file is stored in file storage, not directly in DB.

2. documents.extracted_data stores raw PDF Processor output.

3. documents.approved_data stores final owner-reviewed data.

4. loads row is created only after owner approval.

5. Load can be assigned only when loads.status = CREATED.

6. One load can have one active assignment for MVP.

7. Assignment creates load_assignments row.

8. Assignment updates loads.status = ASSIGNED.

9. SMS notification is sent after assignment is created.

10. SMS failure should not roll back load assignment.

11. SMS success/failure is tracked in notifications table.
```
