erDiagram

    COMPANIES ||--o{ USERS : has
    COMPANIES ||--o{ DRIVERS : owns
    COMPANIES ||--o{ LOADS : manages

    USERS ||--o{ DOCUMENTS : uploads
    USERS ||--o{ EXPENSES : submits

    DRIVERS ||--o{ LOAD_ASSIGNMENTS : assigned
    LOADS ||--o{ LOAD_ASSIGNMENTS : has

    LOADS ||--o{ EXPENSES : has
    LOADS ||--o{ DOCUMENTS : has
    EXPENSES ||--o{ DOCUMENTS : has

    LOADS ||--o| PROFIT_SUMMARY : calculates

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
        decimal driver_pay_amount
        decimal driver_pay_percentage
        varchar assignment_status
        timestamp assigned_at
        timestamp completed_at
    }

    DOCUMENTS {
        bigint id PK
        bigint company_id FK
        bigint uploaded_by_user_id FK
        bigint load_id FK
        bigint expense_id FK
        varchar document_type
        varchar file_name
        varchar file_url
        varchar processing_status
        json extracted_data
        timestamp uploaded_at
        timestamp processed_at
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