/*
Project: Customer Churn Analysis (Synthetic SaaS Dataset)

Overview
This project simulates a Software-as-a-Service (SaaS) subscription business in order to analyze customer churn, recurring revenue, and 
customer lifetime value using SQL.

The script builds a full relational database from scratch and generates synthetic data representing customers, subscription plans, 
subscriptions, and payment transactions between 2020 and 2023.

Key Features
- Generates 50,000 synthetic customers across multiple industries and countries
- Simulates subscription behavior based on company size
- Models churn probabilities for different customer segments
- Generates monthly and annual payment transactions
- Includes indexes to support analytical queries
- Calculates key SaaS metrics such as churn rate, Monthly Recurring Revenue (MRR), and customer lifetime value (LTV)

Database Structure
customers
Stores customer demographic information such as country, industry, and company size.

subscription_plans
Defines available SaaS pricing tiers and billing cycles.

subscriptions
Links customers to subscription plans and tracks start dates, cancellations, and status.

payments
Stores payment transactions associated with subscriptions.

Purpose of the Project
This project demonstrates how SQL can be used to:
- Design a relational schema
- Generate realistic synthetic business data
- Perform churn and revenue analysis
- Calculate key SaaS performance metrics

The script is intended to be run sequentially from top to bottom to build and analyze the dataset.
*/


/*
---------------------------------------------------------
SECTION 1: DATABASE SETUP AND TABLE CREATION
---------------------------------------------------------
Initializes the project database and creates the core
tables used in the SaaS churn analysis simulation.

Tables created:
customers – customer profile information
subscription_plans – pricing tiers and billing cycles
subscriptions – customer subscription lifecycle
payments – subscription payment transactions
*/

CREATE DATABASE IF NOT EXISTS customer_churn;
SHOW DATABASES;
USE customer_churn;

DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS subscription_plans;
DROP TABLE IF EXISTS customers;

/* Customer profile information */
CREATE TABLE customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  created_at DATE NOT NULL,
  country VARCHAR(2) NOT NULL,
  industry VARCHAR(50) NOT NULL,
  company_size VARCHAR(20) NOT NULL);

/* Available subscription plans and pricing tiers */
CREATE TABLE subscription_plans (
  plan_id INT AUTO_INCREMENT PRIMARY KEY,
  plan_name VARCHAR(30) NOT NULL,
  billing_cycle VARCHAR(10) NOT NULL,
  price_usd DECIMAL(10, 2) NOT NULL);

/* Customer subscriptions and lifecycle information */
CREATE TABLE subscriptions (
  subscription_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  plan_id INT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NULL,
  cancel_date DATE NULL,
  status VARCHAR(10) NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  FOREIGN KEY (plan_id) REFERENCES subscription_plans(plan_id));

/* Payment transactions associated with subscriptions */
CREATE TABLE payments (
  payment_id INT AUTO_INCREMENT PRIMARY KEY,
  subscription_id INT NOT NULL,
  payment_date DATE NOT NULL,
  amount_usd DECIMAL(10, 2) NOT NULL,
  payment_status VARCHAR(10) NOT NULL,
  FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id));
  
  SHOW TABLES;

  
/*
---------------------------------------------------------
SECTION 2: SUBSCRIPTION PLAN CONFIGURATION
---------------------------------------------------------
Defines the SaaS pricing tiers used in the simulation.

Each plan tier (Starter, Professional, Business, Enterprise)
is available with both Monthly and Annual billing cycles.
These plans will be used later to assign subscriptions and
calculate metrics such as MRR and customer lifetime value.
*/

INSERT INTO subscription_plans (plan_name, billing_cycle, price_usd) VALUES
('Starter', 'Monthly', 39.00),
('Professional', 'Monthly', 99.00),
('Business', 'Monthly', 249.00),
('Enterprise', 'Monthly', 799.00),
('Starter', 'Annual', 397.80),
('Professional', 'Annual', 1009.80),
('Business', 'Annual', 2539.80),
('Enterprise', 'Annual', 8149.80);

/* Verify that subscription plans were inserted correctly */
SELECT * FROM subscription_plans;


/*
---------------------------------------------------------
SECTION 3: CUSTOMER DATA GENERATION
---------------------------------------------------------
Generates 50,000 synthetic SaaS customers using a recursive
CTE and random distributions for country, industry, and
company size.
*/

/* Increase recursion limit to allow generation of 50,000 rows */
SET SESSION cte_max_recursion_depth = 60000;

/* Generate a sequence from 1 to 50,000 
Each number represents one synthetic customer record.*/
INSERT INTO customers (created_at, country, industry, company_size)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1
  FROM seq
  WHERE n < 50000
),

/*
Generate random values used to simulate customer attributes.
These values will later be converted into categorical variables.
*/
rand_vals AS (
  SELECT
    n,
    RAND() AS r_date,
    RAND() AS r_country,
    RAND() AS r_industry,
    RAND() AS r_size
  FROM seq
)

/* Random signup date between 2020-01-01 and 2023-12-31 */
SELECT
  DATE_ADD('2020-01-01',
    INTERVAL FLOOR(r_date *
      (DATEDIFF('2023-12-31','2020-01-01') + 1)
    ) DAY
  ),

/* Simulated geographic distribution of customers */
  CASE
    WHEN r_country < 0.60 THEN 'US'
    WHEN r_country < 0.70 THEN 'CA'
    WHEN r_country < 0.80 THEN 'UK'
    WHEN r_country < 0.88 THEN 'AU'
    ELSE 'DE'
  END,

/* Assign customers to industries */
  CASE
    WHEN r_industry < 0.30 THEN 'Technology'
    WHEN r_industry < 0.45 THEN 'Finance'
    WHEN r_industry < 0.60 THEN 'Healthcare'
    WHEN r_industry < 0.75 THEN 'Retail'
    WHEN r_industry < 0.90 THEN 'Manufacturing'
    ELSE 'Education'
  END,

/* Assign company size segment */
  CASE
    WHEN r_size < 0.60 THEN 'Small'
    WHEN r_size < 0.90 THEN 'Mid'
    ELSE 'Large'
  END
FROM rand_vals;

/* Alternate verification with labeled output */
SELECT COUNT(*) AS customer_count FROM customers;



/*
---------------------------------------------------------
SECTION 4: SUBSCRIPTION GENERATION
---------------------------------------------------------
Creates subscription records for each customer and simulates
plan selection and churn behavior.

Plan choice is influenced by company size, with larger
companies more likely to select higher tier plans.

Subscriptions start within 14 days of the customer signup
date. Churn probability is also modeled by company size,
resulting in either active or canceled subscriptions.
*/

INSERT INTO subscriptions (customer_id, plan_id, start_date, end_date, cancel_date, status)
SELECT
  c.customer_id,

  /* Assign subscription plan based on company size */
  CASE
    WHEN c.company_size = 'Small' THEN
      CASE
        WHEN RAND() < 0.60 THEN (CASE WHEN RAND() < 0.75 THEN 1 ELSE 5 END)
        ELSE (CASE WHEN RAND() < 0.75 THEN 2 ELSE 6 END)
      END
    WHEN c.company_size = 'Mid' THEN
      CASE
        WHEN RAND() < 0.65 THEN (CASE WHEN RAND() < 0.75 THEN 2 ELSE 6 END)
        ELSE (CASE WHEN RAND() < 0.75 THEN 3 ELSE 7 END)
      END
    ELSE
      CASE
        WHEN RAND() < 0.70 THEN (CASE WHEN RAND() < 0.75 THEN 3 ELSE 7 END)
        ELSE (CASE WHEN RAND() < 0.75 THEN 4 ELSE 8 END)
      END
  END AS plan_id,

  /* Subscription begins within 14 days of customer signup */
  DATE_ADD(c.created_at, INTERVAL FLOOR(RAND() * 14) DAY) AS start_date,

  /* Generate cancellation date for churned customers */
  CASE
    WHEN (
      (c.company_size = 'Small' AND RAND() < 0.24) OR
      (c.company_size = 'Mid' AND RAND() < 0.16) OR
      (c.company_size = 'Large' AND RAND() < 0.10)
    )
    THEN DATE_ADD(
      DATE_ADD(c.created_at, INTERVAL FLOOR(RAND() * 14) DAY),
      INTERVAL FLOOR(30 + RAND() * 700) DAY
    )
    ELSE NULL
  END AS end_date,

  /* Cancel date mirrors end date when churn occurs */
  CASE
    WHEN (
      (c.company_size = 'Small' AND RAND() < 0.24) OR
      (c.company_size = 'Mid' AND RAND() < 0.16) OR
      (c.company_size = 'Large' AND RAND() < 0.10)
    )
    THEN DATE_ADD(
      DATE_ADD(c.created_at, INTERVAL FLOOR(RAND() * 14) DAY),
      INTERVAL FLOOR(30 + RAND() * 700) DAY
    )
    ELSE NULL
  END AS cancel_date,

  /* Determine subscription status */
  CASE
    WHEN (
      (c.company_size = 'Small' AND RAND() < 0.24) OR
      (c.company_size = 'Mid' AND RAND() < 0.16) OR
      (c.company_size = 'Large' AND RAND() < 0.10)
    )
    THEN 'Canceled'
    ELSE 'Active'
  END AS status

FROM customers c;

/* Verify number of generated subscriptions */
SELECT COUNT(*) AS subscription_count FROM subscriptions;

/* Check distribution of active vs canceled subscriptions */
SELECT status, COUNT(*) AS n
FROM subscriptions
GROUP BY status;


/*
---------------------------------------------------------
SECTION 5: REGENERATE SUBSCRIPTIONS (CONSISTENT RANDOMNESS)
---------------------------------------------------------
The previous subscription generation used multiple RAND()
calls inside conditional logic, which can lead to inconsistent
random values within the same row.

This section rebuilds the subscriptions table using a CTE
that generates all random values once per customer. These
values are then reused throughout the query, ensuring
consistent plan selection, start dates, and churn behavior.
*/

/* Disable safe updates to allow table truncation */
SET SQL_SAFE_UPDATES = 0;

/* Remove previously generated subscriptions and payments */
DELETE FROM payments;
DELETE FROM subscriptions;

/* Re-enable safe update protection */
SET SQL_SAFE_UPDATES = 1;

/* Confirm that the subscriptions table is empty */
SELECT status, COUNT(*) FROM subscriptions GROUP BY status;
SELECT COUNT(*) AS subscription_count FROM subscriptions;


/*
Generate subscriptions using precomputed random values
so that each row uses a consistent set of random variables.
*/
INSERT INTO subscriptions (customer_id, plan_id, start_date, end_date, cancel_date, status)

WITH base AS (
  SELECT
    c.customer_id,
    c.created_at,
    c.company_size,

    /* Random variables used throughout subscription simulation */
    RAND() AS r_plan,
    RAND() AS r_cycle,
    RAND() AS r_start_offset,
    RAND() AS r_churn,
    RAND() AS r_churn_days

  FROM customers c
)

SELECT
  b.customer_id,

  /* Assign plan tier based on company size */
  CASE
    WHEN b.company_size = 'Small' THEN
      CASE
        WHEN b.r_plan < 0.60 THEN (CASE WHEN b.r_cycle < 0.75 THEN 1 ELSE 5 END)
        ELSE (CASE WHEN b.r_cycle < 0.75 THEN 2 ELSE 6 END)
      END
    WHEN b.company_size = 'Mid' THEN
      CASE
        WHEN b.r_plan < 0.65 THEN (CASE WHEN b.r_cycle < 0.75 THEN 2 ELSE 6 END)
        ELSE (CASE WHEN b.r_cycle < 0.75 THEN 3 ELSE 7 END)
      END
    ELSE
      CASE
        WHEN b.r_plan < 0.70 THEN (CASE WHEN b.r_cycle < 0.75 THEN 3 ELSE 7 END)
        ELSE (CASE WHEN b.r_cycle < 0.75 THEN 4 ELSE 8 END)
      END
  END AS plan_id,

  /* Subscription start occurs within 14 days of signup */
  DATE_ADD(b.created_at, INTERVAL FLOOR(b.r_start_offset * 14) DAY) AS start_date,

  /* Generate churn end date if customer cancels */
  CASE
    WHEN (
      (b.company_size = 'Small' AND b.r_churn < 0.24) OR
      (b.company_size = 'Mid' AND b.r_churn < 0.16) OR
      (b.company_size = 'Large' AND b.r_churn < 0.10)
    )
    THEN DATE_ADD(
      DATE_ADD(b.created_at, INTERVAL FLOOR(b.r_start_offset * 14) DAY),
      INTERVAL FLOOR(30 + b.r_churn_days * 700) DAY
    )
    ELSE NULL
  END AS end_date,

  /* Cancel date mirrors end date when churn occurs */
  CASE
    WHEN (
      (b.company_size = 'Small' AND b.r_churn < 0.24) OR
      (b.company_size = 'Mid' AND b.r_churn < 0.16) OR
      (b.company_size = 'Large' AND b.r_churn < 0.10)
    )
    THEN DATE_ADD(
      DATE_ADD(b.created_at, INTERVAL FLOOR(b.r_start_offset * 14) DAY),
      INTERVAL FLOOR(30 + b.r_churn_days * 700) DAY
    )
    ELSE NULL
  END AS cancel_date,

  /* Assign final subscription status */
  CASE
    WHEN (
      (b.company_size = 'Small' AND b.r_churn < 0.24) OR
      (b.company_size = 'Mid' AND b.r_churn < 0.16) OR
      (b.company_size = 'Large' AND b.r_churn < 0.10)
    )
    THEN 'Canceled'
    ELSE 'Active'
  END AS status

FROM base b;

/* Check distribution of active vs canceled subscriptions */
SELECT status, COUNT(*) AS n
FROM subscriptions
GROUP BY status;


/*
---------------------------------------------------------
SECTION 6: PAYMENT TRANSACTION GENERATION
---------------------------------------------------------
Generates payment records for all subscriptions based on
their billing cycle.

Monthly subscriptions generate payments every month until
the subscription is canceled or the simulation end date
(December 31, 2023).

Annual subscriptions generate payments once per year until
cancellation or the simulation end date.

Recursive CTEs are used to generate sequences of months
and years that drive the payment schedule.

A small failure rate is introduced to simulate real payment
processing behavior where some transactions fail.
*/

/* Clear existing payment records before regeneration */
SET SQL_SAFE_UPDATES = 0;
DELETE FROM payments;
SET SQL_SAFE_UPDATES = 1;

/* Increase recursion depth for payment schedule generation */
SET SESSION cte_max_recursion_depth = 600000;

INSERT INTO payments (subscription_id, payment_date, amount_usd, payment_status)

WITH RECURSIVE

/* Generate monthly sequence (up to 60 months) */
month_seq AS (
  SELECT 0 AS m
  UNION ALL
  SELECT m + 1
  FROM month_seq
  WHERE m < 60
),

/* Identify subscriptions with monthly billing */
monthly_subs AS (
  SELECT
    s.subscription_id,
    s.start_date,
    COALESCE(s.cancel_date, '2023-12-31') AS end_dt,
    p.price_usd
  FROM subscriptions s
  JOIN subscription_plans p ON p.plan_id = s.plan_id
  WHERE p.billing_cycle = 'Monthly'
),

/* Generate monthly payment schedule */
monthly_payments AS (
  SELECT
    ms.subscription_id,
    DATE_ADD(ms.start_date, INTERVAL month_seq.m MONTH) AS pay_date,
    ms.price_usd
  FROM monthly_subs ms
  JOIN month_seq
    ON DATE_ADD(ms.start_date, INTERVAL month_seq.m MONTH) <= ms.end_dt
),

/* Generate yearly sequence (up to 5 years) */
year_seq AS (
  SELECT 0 AS y
  UNION ALL
  SELECT y + 1
  FROM year_seq
  WHERE y < 5
),

/* Identify subscriptions with annual billing */
annual_subs AS (
  SELECT
    s.subscription_id,
    s.start_date,
    COALESCE(s.cancel_date, '2023-12-31') AS end_dt,
    p.price_usd
  FROM subscriptions s
  JOIN subscription_plans p ON p.plan_id = s.plan_id
  WHERE p.billing_cycle = 'Annual'
),

/* Generate annual payment schedule */
annual_payments AS (
  SELECT
    a.subscription_id,
    DATE_ADD(a.start_date, INTERVAL year_seq.y YEAR) AS pay_date,
    a.price_usd
  FROM annual_subs a
  JOIN year_seq
    ON DATE_ADD(a.start_date, INTERVAL year_seq.y YEAR) <= a.end_dt
)

/* Combine monthly and annual payments */
SELECT
  subscription_id,
  pay_date,
  price_usd,
  CASE WHEN RAND() < 0.05 THEN 'Failed' ELSE 'Success' END
FROM monthly_payments

UNION ALL

SELECT
  subscription_id,
  pay_date,
  price_usd,
  CASE WHEN RAND() < 0.05 THEN 'Failed' ELSE 'Success' END
FROM annual_payments;

/* Verify total number of generated payments */
SELECT COUNT(*) AS payment_count FROM payments;

/* Check success vs failed payment distribution */
SELECT payment_status, COUNT(*) AS n
FROM payments
GROUP BY payment_status;

/* Ensure no payments occur after a subscription was canceled */
SELECT COUNT(*) AS payments_after_cancel
FROM payments p
JOIN subscriptions s ON s.subscription_id = p.subscription_id
WHERE s.cancel_date IS NOT NULL
  AND p.payment_date > s.cancel_date;
  

/*
---------------------------------------------------------
SECTION 7: INDEX CREATION
---------------------------------------------------------
Creates indexes on commonly queried columns to improve
performance for joins, filtering, and analytical queries
used in churn and revenue analysis.
*/

/* Customer signup date analysis */
CREATE INDEX idx_customers_created_at ON customers(created_at);

/* Subscription join and filtering indexes */
CREATE INDEX idx_subscriptions_customer_id ON subscriptions(customer_id);
CREATE INDEX idx_subscriptions_plan_id ON subscriptions(plan_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_start_date ON subscriptions(start_date);
CREATE INDEX idx_subscriptions_cancel_date ON subscriptions(cancel_date);

/* Payment query optimization */
CREATE INDEX idx_payments_subscription_id ON payments(subscription_id);
CREATE INDEX idx_payments_payment_date ON payments(payment_date);
CREATE INDEX idx_payments_status ON payments(payment_status);

/* Verify indexes created on subscriptions table */
SHOW INDEX FROM subscriptions;



/*
---------------------------------------------------------
SECTION 8: CHURN RATE ANALYSIS
---------------------------------------------------------
Calculates monthly customer churn metrics.

A recursive CTE generates a time series of months from
January 2020 through December 2023. Using this time
dimension, the queries calculate:

1. Monthly cancellations
2. Monthly active subscription base
3. Monthly churn rate

Churn rate is defined as:
cancellations during the month divided by the number of
active subscriptions at the beginning of that month.
*/

/* Calculate number of cancellations per month */
WITH RECURSIVE months AS (
  SELECT DATE('2020-01-01') AS month_start
  UNION ALL
  SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
  FROM months
  WHERE month_start < '2023-12-01'
)
SELECT
  m.month_start,
  COUNT(s.subscription_id) AS cancellations
FROM months m
LEFT JOIN subscriptions s
  ON s.cancel_date IS NOT NULL
  AND s.cancel_date >= m.month_start
  AND s.cancel_date < DATE_ADD(m.month_start, INTERVAL 1 MONTH)
GROUP BY m.month_start
ORDER BY m.month_start;


/* Calculate active subscription base for each month */
WITH RECURSIVE months AS (
  SELECT DATE('2020-01-01') AS month_start
  UNION ALL
  SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
  FROM months
  WHERE month_start < '2023-12-01'
)
SELECT
  m.month_start,
  COUNT(s.subscription_id) AS active_base
FROM months m
LEFT JOIN subscriptions s
  ON s.start_date < m.month_start
  AND (s.cancel_date IS NULL OR s.cancel_date >= m.month_start)
GROUP BY m.month_start
ORDER BY m.month_start;


/* Combine cancellations and active base to compute churn rate */
WITH RECURSIVE months AS (
  SELECT DATE('2020-01-01') AS month_start
  UNION ALL
  SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
  FROM months
  WHERE month_start < '2023-12-01'
),
cancellations AS (
  SELECT
    m.month_start,
    COUNT(s.subscription_id) AS cancellations
  FROM months m
  LEFT JOIN subscriptions s
    ON s.cancel_date IS NOT NULL
    AND s.cancel_date >= m.month_start
    AND s.cancel_date < DATE_ADD(m.month_start, INTERVAL 1 MONTH)
  GROUP BY m.month_start
),
active_base AS (
  SELECT
    m.month_start,
    COUNT(s.subscription_id) AS active_base
  FROM months m
  LEFT JOIN subscriptions s
    ON s.start_date < m.month_start
    AND (s.cancel_date IS NULL OR s.cancel_date >= m.month_start)
  GROUP BY m.month_start
)
SELECT
  c.month_start,
  c.cancellations,
  a.active_base,
  ROUND(c.cancellations / a.active_base, 4) AS churn_rate
FROM cancellations c
JOIN active_base a ON a.month_start = c.month_start
ORDER BY c.month_start;



/*
---------------------------------------------------------
SECTION 9: MONTHLY RECURRING REVENUE (MRR)
---------------------------------------------------------
Calculates Monthly Recurring Revenue over time.

A recursive CTE generates a monthly time series from
January 2020 through December 2023. For each month,
active subscriptions are identified and their revenue
contribution is aggregated.

Monthly plans contribute their full monthly price.
Annual plans are normalized to monthly revenue by
dividing the annual price by 12.
*/

/* Generate monthly time series and compute MRR */
WITH RECURSIVE months AS (
  SELECT DATE('2020-01-01') AS month_start
  UNION ALL
  SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
  FROM months
  WHERE month_start < '2023-12-01'
)

SELECT
  m.month_start,

  /* Sum revenue from active subscriptions */
  ROUND(SUM(
    CASE
      WHEN p.billing_cycle = 'Monthly' THEN p.price_usd
      ELSE p.price_usd / 12
    END
  ), 2) AS mrr_usd

FROM months m

JOIN subscriptions s
  ON s.start_date < m.month_start
  AND (s.cancel_date IS NULL OR s.cancel_date >= m.month_start)

JOIN subscription_plans p
  ON p.plan_id = s.plan_id

GROUP BY m.month_start
ORDER BY m.month_start;




/*
---------------------------------------------------------
SECTION 10: LIFETIME VALUE AND REVENUE ANALYSIS
---------------------------------------------------------
Analyzes customer lifetime revenue and subscription
performance using payment transaction data.

The queries in this section calculate:

• Lifetime revenue per subscription
• Data quality checks for missing or failed payments
• Aggregate customer lifetime value statistics
• Revenue and LTV by subscription plan
• Customer churn rates by plan tier
• Revenue churn rates by plan tier
*/

/* Calculate lifetime revenue per subscription (successful payments only) */
SELECT
  s.subscription_id,
  SUM(p.amount_usd) AS lifetime_revenue
FROM subscriptions s
JOIN payments p
  ON p.subscription_id = s.subscription_id
WHERE p.payment_status = 'Success'
GROUP BY s.subscription_id;


/* Identify subscriptions with no successful payments */
SELECT COUNT(*) AS subs_with_no_success
FROM subscriptions s
WHERE NOT EXISTS (
  SELECT 1 FROM payments p
  WHERE p.subscription_id = s.subscription_id
    AND p.payment_status = 'Success'
);


/* Identify subscriptions with no payment records at all */
SELECT COUNT(*) AS subs_with_no_payments
FROM subscriptions s
LEFT JOIN payments p ON p.subscription_id = s.subscription_id
WHERE p.payment_id IS NULL;


/* Identify subscriptions where all payments failed */
SELECT COUNT(*) AS subs_only_failed
FROM (
  SELECT p.subscription_id,
         SUM(p.payment_status = 'Success') AS success_count,
         COUNT(*) AS total_payments
  FROM payments p
  GROUP BY p.subscription_id
) t
WHERE t.success_count = 0
  AND t.total_payments > 0;


/* Inspect example subscriptions without successful payments */
SELECT s.subscription_id, s.customer_id, s.start_date, s.cancel_date, s.status
FROM subscriptions s
WHERE NOT EXISTS (
  SELECT 1 FROM payments p
  WHERE p.subscription_id = s.subscription_id
    AND p.payment_status = 'Success'
)
LIMIT 20;


/* Aggregate lifetime value statistics across all subscriptions */
SELECT
  COUNT(*) AS total_subs,
  SUM(lifetime_revenue) AS total_revenue,
  ROUND(AVG(lifetime_revenue),2) AS avg_ltv,
  MIN(lifetime_revenue) AS min_ltv,
  MAX(lifetime_revenue) AS max_ltv
FROM (
  SELECT s.subscription_id,
         IFNULL(SUM(p.amount_usd),0) AS lifetime_revenue
  FROM subscriptions s
  LEFT JOIN payments p
    ON p.subscription_id = s.subscription_id
    AND p.payment_status = 'Success'
  GROUP BY s.subscription_id
) t;


/* Analyze lifetime value and revenue contribution by plan tier */
SELECT
  p.plan_name,
  p.billing_cycle,
  COUNT(*) AS n_subs,
  ROUND(AVG(t.lifetime_revenue),2) AS avg_ltv,
  ROUND(SUM(t.lifetime_revenue),2) AS total_revenue
FROM subscriptions s
JOIN subscription_plans p ON p.plan_id = s.plan_id
LEFT JOIN (
  SELECT subscription_id, IFNULL(SUM(amount_usd),0) AS lifetime_revenue
  FROM payments
  WHERE payment_status = 'Success'
  GROUP BY subscription_id
) t ON t.subscription_id = s.subscription_id
GROUP BY p.plan_name, p.billing_cycle
ORDER BY total_revenue DESC;


/* Calculate churn rate by subscription plan */
SELECT
  p.plan_name,
  p.billing_cycle,
  COUNT(*) AS total_subs,
  SUM(s.status = 'Canceled') AS churned_subs,
  ROUND(SUM(s.status = 'Canceled') / COUNT(*), 4) AS churn_rate
FROM subscriptions s
JOIN subscription_plans p
  ON p.plan_id = s.plan_id
GROUP BY p.plan_name, p.billing_cycle
ORDER BY churn_rate DESC;


/* Calculate revenue churn rate by plan */
SELECT
  p.plan_name,
  p.billing_cycle,
  SUM(CASE WHEN s.status = 'Canceled' THEN pl.price_usd ELSE 0 END) AS churned_mrr,
  SUM(pl.price_usd) AS total_mrr,
  ROUND(
    SUM(CASE WHEN s.status = 'Canceled' THEN pl.price_usd ELSE 0 END)
    / SUM(pl.price_usd),
    4
  ) AS revenue_churn_rate
FROM subscriptions s
JOIN subscription_plans pl
  ON pl.plan_id = s.plan_id
JOIN subscription_plans p
  ON p.plan_id = s.plan_id
GROUP BY p.plan_name, p.billing_cycle
ORDER BY revenue_churn_rate DESC;



/*
---------------------------------------------------------
SECTION 11: KPI VIEWS FOR DASHBOARDS
---------------------------------------------------------
Creates reusable SQL views that summarize key churn and
revenue metrics. These views are designed to support a BI
dashboard (Tableau, Power BI) without rewriting queries.
*/

/* Overall churn KPIs */
DROP VIEW IF EXISTS v_kpis;
CREATE VIEW v_kpis AS
SELECT
  COUNT(*) AS total_subscriptions,
  SUM(status = 'Canceled') AS total_churned,
  ROUND(SUM(status = 'Canceled') / COUNT(*), 4) AS churn_rate
FROM subscriptions;


/* Churn rate by plan tier and billing cycle */
DROP VIEW IF EXISTS v_plan_churn;
CREATE VIEW v_plan_churn AS
SELECT
  p.plan_name,
  p.billing_cycle,
  COUNT(*) AS total_subs,
  SUM(s.status = 'Canceled') AS churned_subs,
  ROUND(SUM(s.status = 'Canceled') / COUNT(*), 4) AS churn_rate
FROM subscriptions s
JOIN subscription_plans p
  ON p.plan_id = s.plan_id
GROUP BY
  p.plan_name,
  p.billing_cycle;


/* Monthly Recurring Revenue (MRR) time series */
DROP VIEW IF EXISTS v_monthly_mrr;
CREATE VIEW v_monthly_mrr AS
WITH RECURSIVE months AS (
  SELECT DATE('2020-01-01') AS month_start
  UNION ALL
  SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
  FROM months
  WHERE month_start < '2023-12-01'
)
SELECT
  m.month_start,
  ROUND(SUM(
    CASE
      WHEN pl.billing_cycle = 'Monthly' THEN pl.price_usd
      ELSE pl.price_usd / 12
    END
  ), 2) AS mrr
FROM months m
LEFT JOIN subscriptions s
  ON s.start_date < m.month_start
  AND (s.cancel_date IS NULL OR s.cancel_date >= m.month_start)
LEFT JOIN subscription_plans pl
  ON pl.plan_id = s.plan_id
GROUP BY m.month_start
ORDER BY m.month_start;


/* Quick checks to view results */
SELECT * FROM v_kpis;
SELECT * FROM v_plan_churn;
SELECT * FROM v_monthly_mrr;



/*
---------------------------------------------------------
SECTION 12: ADDITIONAL DASHBOARD VIEWS
---------------------------------------------------------
Adds reusable views for plan level lifetime value and
monthly churn metrics to support BI dashboards.
*/

/* Lifetime value (LTV) by plan tier and billing cycle */
DROP VIEW IF EXISTS v_ltv_by_plan;
CREATE VIEW v_ltv_by_plan AS
WITH ltv_by_sub AS (
  SELECT
    s.subscription_id,
    s.plan_id,
    IFNULL(SUM(p.amount_usd), 0) AS lifetime_revenue
  FROM subscriptions s
  LEFT JOIN payments p
    ON p.subscription_id = s.subscription_id
    AND p.payment_status = 'Success'
  GROUP BY
    s.subscription_id,
    s.plan_id
)
SELECT
  sp.plan_name,
  sp.billing_cycle,
  COUNT(*) AS n_subs,
  ROUND(AVG(l.lifetime_revenue), 2) AS avg_ltv,
  ROUND(SUM(l.lifetime_revenue), 2) AS total_revenue
FROM ltv_by_sub l
JOIN subscription_plans sp
  ON sp.plan_id = l.plan_id
GROUP BY
  sp.plan_name,
  sp.billing_cycle
ORDER BY total_revenue DESC;


/* Monthly churn metrics (cancellations, active base, churn rate) */
DROP VIEW IF EXISTS v_churn_by_month;
CREATE VIEW v_churn_by_month AS
WITH RECURSIVE months AS (
  SELECT DATE('2020-01-01') AS month_start
  UNION ALL
  SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
  FROM months
  WHERE month_start < '2023-12-01'
),
cancellations AS (
  SELECT
    m.month_start,
    COUNT(s.subscription_id) AS cancellations
  FROM months m
  LEFT JOIN subscriptions s
    ON s.cancel_date IS NOT NULL
    AND s.cancel_date >= m.month_start
    AND s.cancel_date < DATE_ADD(m.month_start, INTERVAL 1 MONTH)
  GROUP BY m.month_start
),
active_base AS (
  SELECT
    m.month_start,
    COUNT(s.subscription_id) AS active_base
  FROM months m
  LEFT JOIN subscriptions s
    ON s.start_date < m.month_start
    AND (s.cancel_date IS NULL OR s.cancel_date >= m.month_start)
  GROUP BY m.month_start
)
SELECT
  c.month_start,
  c.cancellations,
  a.active_base,
  ROUND(c.cancellations / NULLIF(a.active_base, 0), 4) AS churn_rate
FROM cancellations c
JOIN active_base a
  ON a.month_start = c.month_start
ORDER BY c.month_start;


/* Quick checks */
SELECT * FROM v_ltv_by_plan;
SELECT * FROM v_churn_by_month;



/*
---------------------------------------------------------
SECTION 13: FINAL SANITY CHECKS
---------------------------------------------------------
Confirms row counts and validates that dashboard views
return results after a full script run.
*/

SELECT COUNT(*) AS customer_count FROM customers;
SELECT COUNT(*) AS subscription_count FROM subscriptions;
SELECT COUNT(*) AS payment_count FROM payments;

SELECT COUNT(*) AS v_kpis_rows FROM v_kpis;
SELECT COUNT(*) AS v_plan_churn_rows FROM v_plan_churn;
SELECT COUNT(*) AS v_monthly_mrr_rows FROM v_monthly_mrr;
SELECT COUNT(*) AS v_ltv_by_plan_rows FROM v_ltv_by_plan;
SELECT COUNT(*) AS v_churn_by_month_rows FROM v_churn_by_month;




/* 
Export queries used to generate CSV files for the Tableau dashboard
Each query pulls from the analytical views created above
*/

SELECT * FROM v_kpis;
SELECT * FROM v_plan_churn;
SELECT * FROM v_monthly_mrr;
SELECT * FROM v_ltv_by_plan;
SELECT * FROM v_churn_by_month;







