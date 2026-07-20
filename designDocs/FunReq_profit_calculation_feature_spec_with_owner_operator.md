# Feature Spec: Profit Calculation Dashboard

## Functional Requirement

Trucking company owner should be able to view profit filtered by:

```text
Time range
Load
Driver
```

The dashboard should calculate gross revenue, expenses, driver / owner-operator payout, net profit, and profit margin.

## Core Goal

Show company owner how much money the company made after subtracting applicable expenses and payouts.

```text
Net Profit = Gross Revenue - Applicable Costs
```

```text
Profit Margin % = Net Profit / Gross Revenue * 100
```

## Important Driver Type Rule

Profit calculation depends on the assigned driver's `driver_type`.

Supported driver types:

```text
COMPANY_DRIVER
OWNER_OPERATOR
```

### Company Driver

For company drivers:

```text
Company receives full load revenue.
Company pays load expenses.
Company pays driver.
Company profit = revenue - load expenses - driver payout.
```

### Owner Operator

For owner-operators:

```text
Company receives only its share of the load revenue.
Owner-operator handles their own expenses.
Company profit = gross revenue - owner-operator payout.
```

Owner-operator expenses should not reduce company-owner profit.

Even if an owner-operator uploads expenses, those expenses are ignored for company profit calculation because the owner-operator is responsible for their own expenses.

## Tables Used

- `companies`
- `users`
- `drivers`
- `loads`
- `load_assignments`
- `expenses`

Optional future table:

- `profit_summary`

## Revenue Source

For MVP:

```text
Revenue = loads.gross_revenue
```

Use `loads.delivery_date` for time-based revenue filtering.

Example:

```text
If owner filters June 1 to June 30:
include loads where delivery_date is between June 1 and June 30.
```

## Cost Sources

Costs come from:

```text
expenses
load_assignments
```

But expenses are treated differently based on whether the load is assigned to a company driver or owner-operator.

## Expense Scopes

Expenses should have an `expense_scope` field.

```text
LOAD
DRIVER
COMPANY
```

| Scope | Meaning | Example |
|---|---|---|
| `LOAD` | Expense belongs to specific load | Fuel, toll, lumper |
| `DRIVER` | Expense belongs to driver but not specific load | Driver advance, driver hotel |
| `COMPANY` | General company expense | Insurance, software, permits |

## Required Expense Schema Update

`expenses` should support optional load/driver links.

```sql
CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,

    company_id BIGINT NOT NULL REFERENCES companies(id),

    load_id BIGINT REFERENCES loads(id),
    driver_id BIGINT REFERENCES drivers(id),
    submitted_by_user_id BIGINT NOT NULL REFERENCES users(id),

    expense_scope VARCHAR(50) NOT NULL,

    expense_type VARCHAR(100) NOT NULL,
    vendor_name VARCHAR(255),
    amount DECIMAL(12,2) NOT NULL,
    expense_date DATE,
    status VARCHAR(50) DEFAULT 'SUBMITTED',
    notes TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Driver / Owner-Operator Payout Source

Payout comes from `load_assignments`.

Fields:

```text
payout_type
driver_pay_amount
driver_pay_percentage
```

Payout calculation:

```text
If payout_type = FLAT_AMOUNT:
    payout = driver_pay_amount

If payout_type = PERCENTAGE:
    payout = loads.gross_revenue * driver_pay_percentage / 100
```

For owner-operators:

```text
driver_pay_percentage = owner-operator's percentage share of gross revenue
```

Example:

```text
Load gross revenue = $2,500
Owner-operator share = 80%
Company share = 20%

Owner-operator payout = 2500 * 80 / 100 = $2,000
Company profit = 2500 - 2000 = $500
```

## Load-Level Profit

Used when owner filters by one load.

### If Assigned Driver is COMPANY_DRIVER

Formula:

```text
Load Profit =
    Load Gross Revenue
    - Load-Level Expenses
    - Driver Pay
```

Where:

```text
Load-Level Expenses =
    SUM(expenses.amount)
    WHERE expense_scope = LOAD
      AND load_id = selected_load_id
```

Example:

```text
Load revenue: $2,500
Fuel: $500
Toll: $100
Driver payout: $1,000

Load profit = 2500 - 500 - 100 - 1000
Load profit = $900
```

### If Assigned Driver is OWNER_OPERATOR

Formula:

```text
Load Profit =
    Load Gross Revenue
    - Owner Operator Payout
```

or:

```text
Load Profit =
    Load Gross Revenue * Company Share Percentage
```

Do not subtract owner-operator uploaded expenses.

Example:

```text
Load revenue: $2,500
Owner-operator payout percentage: 80%
Owner-operator payout: $2,000
Company share: 20%

Load profit = 2500 - 2000
Load profit = $500
```

## Driver-Level Profit

Used when owner filters by driver and time range.

### If Driver Type is COMPANY_DRIVER

Formula:

```text
Driver Profit =
    Revenue from loads assigned to driver
    - Load expenses for those loads
    - Driver payout for those loads
    - Driver-level expenses
```

Where driver-level expenses are:

```text
expense_scope = DRIVER
AND driver_id = selected_driver_id
```

Example:

```text
Assigned load revenue: $5,500
Load expenses: $1,300
Driver payouts: $2,200
Driver-level expenses: $450

Driver profit = 5500 - 1300 - 2200 - 450
Driver profit = $1,550
```

### If Driver Type is OWNER_OPERATOR

From the company owner's perspective, this means:

```text
Company Profit From Owner Operator =
    Gross revenue from owner-operator loads
    - Owner-operator payouts
```

or:

```text
Company Profit From Owner Operator =
    Gross revenue from owner-operator loads * company share percentage
```

Do not subtract owner-operator `LOAD` or `DRIVER` expenses.

Example:

```text
Owner-operator load revenue: $10,000
Owner-operator share: 80%
Company share: 20%

Company profit from owner-operator = $2,000
```

## Company-Level Profit

Used when owner filters by time range only.

Company-level profit combines:

```text
Profit from company-driver loads
+ Profit from owner-operator loads
- Company-level expenses
```

### Company-Driver Load Profit

```text
Company-driver load profit =
    Gross revenue
    - Load expenses
    - Company driver payout
```

### Owner-Operator Load Profit

```text
Owner-operator load profit =
    Gross revenue
    - Owner-operator payout
```

Owner-operator expenses are not subtracted.

### Company-Level Formula

```text
Company Profit =
    Profit from company-driver loads
    + Profit from owner-operator loads
    - Company-level expenses
```

Company-level expenses are:

```text
expense_scope = COMPANY
```

## How Expense Scope Affects Profit

### For COMPANY_DRIVER Loads

| Expense Scope | Load Profit | Driver Profit | Company Profit |
|---|---:|---:|---:|
| `LOAD` | Yes | Yes | Yes |
| `DRIVER` | No | Yes | Yes |
| `COMPANY` | No | No by default | Yes |

### For OWNER_OPERATOR Loads

| Expense Scope | Load Profit | Owner-Operator View | Company Profit |
|---|---:|---:|---:|
| `LOAD` | No | Not used for company owner profit | No |
| `DRIVER` | No | Not used for company owner profit | No |
| `COMPANY` | No | No | Yes |

Important rule:

```text
Owner-operator expenses do not reduce company-owner profit.
```

## Date Filtering Rules

For MVP:

```text
Revenue:
    use loads.delivery_date

Expenses:
    use expenses.expense_date

Payout:
    use loads.delivery_date for assigned loads
```

Example:

```text
Owner selects June 1 to June 30.

Revenue:
    loads where delivery_date between June 1 and June 30

Expenses:
    expenses where expense_date between June 1 and June 30

Payout:
    assignments for loads where delivery_date between June 1 and June 30
```

## Expense Status Rule

For MVP dashboard, include:

```text
SUBMITTED
APPROVED
```

Later, dashboard can split:

```text
Estimated Profit = SUBMITTED + APPROVED expenses
Actual Profit = APPROVED expenses only
```

## Dashboard Metrics

Return these fields:

```text
grossRevenue
companyDriverLoadExpenses
companyDriverPayout
ownerOperatorPayout
driverExpenses
companyExpenses
totalCosts
netProfit
profitMarginPercentage
```

Formula:

```text
totalCosts =
    companyDriverLoadExpenses
    + companyDriverPayout
    + ownerOperatorPayout
    + driverExpenses
    + companyExpenses
```

Important:

```text
Do not include owner-operator uploaded expenses in totalCosts for company-owner profit.
```

Formula:

```text
netProfit = grossRevenue - totalCosts
```

Formula:

```text
profitMarginPercentage =
    netProfit / grossRevenue * 100
```

If `grossRevenue = 0`, return profit margin as `0` or `null`.

## API: Profit Summary

```http
GET /api/v1/profit-summary
Authorization: Bearer <token>
```

Query params:

```text
startDate=2026-06-01
endDate=2026-06-30
loadId=optional
driverId=optional
```

Rules:

```text
If loadId is provided:
    return load-level profit using assigned driver_type.

If driverId is provided:
    return driver-level profit using driver_type.

If only startDate/endDate are provided:
    return company-level profit.

If loadId and driverId are both provided:
    validate load is assigned to driver, then return profit for that load/driver context.
```

Response:

```json
{
  "filter": {
    "startDate": "2026-06-01",
    "endDate": "2026-06-30",
    "loadId": null,
    "driverId": null
  },
  "grossRevenue": 10000.00,
  "companyDriverLoadExpenses": 1200.00,
  "companyDriverPayout": 2500.00,
  "ownerOperatorPayout": 3200.00,
  "driverExpenses": 300.00,
  "companyExpenses": 800.00,
  "totalCosts": 8000.00,
  "netProfit": 2000.00,
  "profitMarginPercentage": 20.00
}
```

## SQL: Load-Level Profit With Driver Type

```sql
SELECT
    l.id AS load_id,
    l.load_number,
    l.gross_revenue,
    d.driver_type,

    COALESCE(SUM(
        CASE
            WHEN d.driver_type = 'COMPANY_DRIVER'
             AND e.expense_scope = 'LOAD'
            THEN e.amount
            ELSE 0
        END
    ), 0) AS applicable_load_expenses,

    CASE
        WHEN la.payout_type = 'FLAT_AMOUNT'
            THEN COALESCE(la.driver_pay_amount, 0)
        WHEN la.payout_type = 'PERCENTAGE'
            THEN COALESCE(l.gross_revenue * la.driver_pay_percentage / 100, 0)
        ELSE 0
    END AS payout,

    CASE
        WHEN d.driver_type = 'COMPANY_DRIVER' THEN
            l.gross_revenue
            - COALESCE(SUM(
                CASE
                    WHEN e.expense_scope = 'LOAD' THEN e.amount
                    ELSE 0
                END
              ), 0)
            - CASE
                WHEN la.payout_type = 'FLAT_AMOUNT'
                    THEN COALESCE(la.driver_pay_amount, 0)
                WHEN la.payout_type = 'PERCENTAGE'
                    THEN COALESCE(l.gross_revenue * la.driver_pay_percentage / 100, 0)
                ELSE 0
              END

        WHEN d.driver_type = 'OWNER_OPERATOR' THEN
            l.gross_revenue
            - CASE
                WHEN la.payout_type = 'FLAT_AMOUNT'
                    THEN COALESCE(la.driver_pay_amount, 0)
                WHEN la.payout_type = 'PERCENTAGE'
                    THEN COALESCE(l.gross_revenue * la.driver_pay_percentage / 100, 0)
                ELSE 0
              END

        ELSE 0
    END AS net_profit

FROM loads l
JOIN load_assignments la
    ON la.load_id = l.id
   AND la.assignment_status IN ('ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED')
JOIN drivers d
    ON d.id = la.driver_id
LEFT JOIN expenses e
    ON e.load_id = l.id
   AND e.status IN ('SUBMITTED', 'APPROVED')

WHERE l.id = :loadId
  AND l.company_id = :companyId

GROUP BY
    l.id,
    l.load_number,
    l.gross_revenue,
    d.driver_type,
    la.payout_type,
    la.driver_pay_amount,
    la.driver_pay_percentage;
```

## SQL: Company Profit by Time With Owner-Operator Logic

```sql
WITH assigned_loads AS (
    SELECT
        l.id AS load_id,
        l.company_id,
        l.gross_revenue,
        l.delivery_date,
        d.id AS driver_id,
        d.driver_type,
        la.payout_type,
        la.driver_pay_amount,
        la.driver_pay_percentage,
        CASE
            WHEN la.payout_type = 'FLAT_AMOUNT'
                THEN COALESCE(la.driver_pay_amount, 0)
            WHEN la.payout_type = 'PERCENTAGE'
                THEN COALESCE(l.gross_revenue * la.driver_pay_percentage / 100, 0)
            ELSE 0
        END AS payout
    FROM loads l
    JOIN load_assignments la ON la.load_id = l.id
    JOIN drivers d ON d.id = la.driver_id
    WHERE l.company_id = :companyId
      AND l.delivery_date BETWEEN :startDate AND :endDate
      AND la.assignment_status IN ('ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED')
),

company_driver_load_expenses AS (
    SELECT
        e.company_id,
        SUM(e.amount) AS company_driver_load_expenses
    FROM expenses e
    JOIN assigned_loads al ON al.load_id = e.load_id
    WHERE e.company_id = :companyId
      AND e.expense_scope = 'LOAD'
      AND e.status IN ('SUBMITTED', 'APPROVED')
      AND al.driver_type = 'COMPANY_DRIVER'
    GROUP BY e.company_id
),

driver_expenses AS (
    SELECT
        e.company_id,
        SUM(e.amount) AS driver_expenses
    FROM expenses e
    JOIN drivers d ON d.id = e.driver_id
    WHERE e.company_id = :companyId
      AND e.expense_scope = 'DRIVER'
      AND e.expense_date BETWEEN :startDate AND :endDate
      AND e.status IN ('SUBMITTED', 'APPROVED')
      AND d.driver_type = 'COMPANY_DRIVER'
    GROUP BY e.company_id
),

company_expenses AS (
    SELECT
        company_id,
        SUM(amount) AS company_expenses
    FROM expenses
    WHERE company_id = :companyId
      AND expense_scope = 'COMPANY'
      AND expense_date BETWEEN :startDate AND :endDate
      AND status IN ('SUBMITTED', 'APPROVED')
    GROUP BY company_id
),

summary AS (
    SELECT
        company_id,
        SUM(gross_revenue) AS gross_revenue,

        SUM(
            CASE WHEN driver_type = 'COMPANY_DRIVER'
                 THEN payout ELSE 0 END
        ) AS company_driver_payout,

        SUM(
            CASE WHEN driver_type = 'OWNER_OPERATOR'
                 THEN payout ELSE 0 END
        ) AS owner_operator_payout

    FROM assigned_loads
    GROUP BY company_id
)

SELECT
    COALESCE(s.gross_revenue, 0) AS gross_revenue,
    COALESCE(cdle.company_driver_load_expenses, 0) AS company_driver_load_expenses,
    COALESCE(s.company_driver_payout, 0) AS company_driver_payout,
    COALESCE(s.owner_operator_payout, 0) AS owner_operator_payout,
    COALESCE(de.driver_expenses, 0) AS driver_expenses,
    COALESCE(ce.company_expenses, 0) AS company_expenses,

    COALESCE(cdle.company_driver_load_expenses, 0)
    + COALESCE(s.company_driver_payout, 0)
    + COALESCE(s.owner_operator_payout, 0)
    + COALESCE(de.driver_expenses, 0)
    + COALESCE(ce.company_expenses, 0) AS total_costs,

    COALESCE(s.gross_revenue, 0)
    - COALESCE(cdle.company_driver_load_expenses, 0)
    - COALESCE(s.company_driver_payout, 0)
    - COALESCE(s.owner_operator_payout, 0)
    - COALESCE(de.driver_expenses, 0)
    - COALESCE(ce.company_expenses, 0) AS net_profit

FROM summary s
LEFT JOIN company_driver_load_expenses cdle ON cdle.company_id = s.company_id
LEFT JOIN driver_expenses de ON de.company_id = s.company_id
LEFT JOIN company_expenses ce ON ce.company_id = s.company_id;
```

## Recommended Future Schema Additions

### Add to `loads`

```text
delivered_at
completed_at
```

Reason:

```text
Profit by time should eventually use delivered/completed timestamp instead of only delivery_date.
```

### Add to `load_assignments`

```text
final_driver_pay
company_share_percentage
```

Reason:

```text
If percentage-based payout changes due to revenue adjustment, final_driver_pay can freeze the settlement value.
company_share_percentage can make owner-operator company share explicit instead of calculating 100 - driver_pay_percentage.
```

For MVP, calculate dynamically.

## MVP Rules

```text
1. Revenue = loads.gross_revenue.

2. For company-driver load profit:
   load revenue - load expenses - driver payout.

3. For owner-operator load profit:
   load revenue - owner-operator payout.

4. Owner-operator uploaded expenses are ignored for company-owner profit.

5. Driver-level expenses are subtracted only for company drivers.

6. Company profit =
   company-driver load profit
   + owner-operator load profit
   - company expenses.

7. Use delivery_date for revenue filtering.

8. Use expense_date for expense filtering.

9. Include SUBMITTED + APPROVED expenses in dashboards.

10. Later separate Actual Profit and Estimated Profit.
```

## Important Design Rules

```text
LOAD expenses affect company profit only for COMPANY_DRIVER loads.

OWNER_OPERATOR load expenses do not reduce company-owner profit.

DRIVER expenses affect company profit only for COMPANY_DRIVER drivers.

COMPANY expenses always affect company-level profit.

Driver / owner-operator payout is always a cost to the company.

Owner-operator payout is usually percentage-based.

Company-level expenses should not reduce individual load profit unless expense allocation is added later.
```
