-- Capstone Project: SQL Data Quality Audits & Business Queries
-- Author: Rudhiyansh Sandanshiv

USE capstone;

-- ============================================================================
-- PART 1: DATA QUALITY AUDITS (Checking raw data issues)
-- ============================================================================

-- Audit 1: Find duplicate customer emails
SELECT 
    email, 
    COUNT(*) AS dup_count,
    GROUP_CONCAT(name SEPARATOR ' | ') AS names,
    GROUP_CONCAT(customer_id SEPARATOR ', ') AS ids
FROM Customers
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY dup_count DESC;


-- Audit 2: Check for orphan order items (order_id doesn't exist in Orders)
SELECT 
    oi.order_item_id, 
    oi.order_id, 
    oi.product_id, 
    oi.quantity,
    oi.discount_pct
FROM OrderItems oi
LEFT JOIN Orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- Audit 3: Check for zero or negative quantities
SELECT 
    order_item_id, 
    order_id, 
    product_id, 
    quantity
FROM OrderItems
WHERE quantity <= 0;


-- Audit 4: Find customers with missing (NULL) region
SELECT 
    customer_id, 
    name, 
    email, 
    signup_date, 
    region_id, 
    segment
FROM Customers
WHERE region_id IS NULL;



-- ============================================================================
-- PART 2: BUSINESS ANALYTICS QUERIES
-- ============================================================================

-- Query 1: Regional Sales Performance & Revenue Share
-- Calculates orders, customers, net revenue and revenue % by region (Delivered orders only)
SELECT 
    COALESCE(r.region_name, 'Unknown') AS region_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    ROUND(SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)), 2) AS net_revenue,
    ROUND(
        SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)) / 
        SUM(SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct))) OVER () * 100, 
        2
    ) AS revenue_share_pct
FROM Orders o
JOIN Customers c ON o.customer_id = c.customer_id
LEFT JOIN Region r ON c.region_id = r.region_id
JOIN OrderItems oi ON o.order_id = oi.order_id
JOIN Products p ON oi.product_id = p.product_id
WHERE o.status = 'Delivered' 
  AND oi.quantity > 0
GROUP BY r.region_name
ORDER BY net_revenue ASC;


-- Query 2: Month-over-Month (MoM) Revenue Growth Trend
-- Uses CTE and LAG() window function to calculate monthly growth rate %
WITH MonthlyRevenue AS (
    SELECT 
        DATE_FORMAT(o.order_date, '%Y-%m') AS sales_month,
        ROUND(SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)), 2) AS current_month_revenue
    FROM Orders o
    JOIN OrderItems oi ON o.order_id = oi.order_id
    JOIN Products p ON oi.product_id = p.product_id
    WHERE o.status = 'Delivered' 
      AND oi.quantity > 0
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT 
    sales_month,
    current_month_revenue,
    LAG(current_month_revenue, 1) OVER (ORDER BY sales_month) AS previous_month_revenue,
    ROUND(
        ((current_month_revenue - LAG(current_month_revenue, 1) OVER (ORDER BY sales_month)) 
        / LAG(current_month_revenue, 1) OVER (ORDER BY sales_month)) * 100, 
        2
    ) AS mom_growth_pct
FROM MonthlyRevenue
ORDER BY sales_month ASC;


-- Query 3: Top 3 Spending Customers in Each Region
-- Uses DENSE_RANK() partitioned by region to rank customers by total spend
WITH CustomerSpending AS (
    SELECT 
        r.region_name,
        c.customer_id,
        c.name AS customer_name,
        ROUND(SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)), 2) AS total_spent,
        DENSE_RANK() OVER (
            PARTITION BY r.region_name 
            ORDER BY SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)) DESC
        ) AS rank_in_region
    FROM Customers c
    JOIN Region r ON c.region_id = r.region_id
    JOIN Orders o ON c.customer_id = o.customer_id
    JOIN OrderItems oi ON o.order_id = oi.order_id
    JOIN Products p ON oi.product_id = p.product_id
    WHERE o.status = 'Delivered' 
      AND oi.quantity > 0
    GROUP BY r.region_name, c.customer_id, c.name
)
SELECT 
    region_name,
    rank_in_region,
    customer_id,
    customer_name,
    total_spent
FROM CustomerSpending
WHERE rank_in_region <= 3
ORDER BY region_name, rank_in_region;


-- Query 4: Category Profitability (Revenue, COGS, Net Profit & Profit Margin %)
SELECT 
    p.category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)), 2) AS net_revenue,
    ROUND(SUM(oi.quantity * p.cost_price), 2) AS total_cogs,
    ROUND(SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)) - SUM(oi.quantity * p.cost_price), 2) AS net_profit,
    ROUND(
        ((SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)) - SUM(oi.quantity * p.cost_price)) 
        / SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct))) * 100, 
        2
    ) AS profit_margin_pct
FROM OrderItems oi
JOIN Products p ON oi.product_id = p.product_id
JOIN Orders o ON oi.order_id = o.order_id
WHERE o.status = 'Delivered' 
  AND oi.quantity > 0
GROUP BY p.category
ORDER BY net_profit DESC;


-- Query 5: Customer Churn Risk Flagging (Inactive > 90 Days)
-- Flags delivered customers whose last purchase was more than 90 days before the latest date
WITH MaxOrderDate AS (
    SELECT MAX(order_date) AS dataset_latest_date FROM Orders
),
CustomerActivity AS (
    SELECT 
        c.customer_id,
        c.name,
        c.email,
        c.segment,
        MAX(o.order_date) AS last_order_date,
        COUNT(DISTINCT o.order_id) AS total_orders_placed,
        ROUND(SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)), 2) AS historical_spend
    FROM Customers c
    JOIN Orders o ON c.customer_id = o.customer_id
    JOIN OrderItems oi ON o.order_id = oi.order_id
    JOIN Products p ON oi.product_id = p.product_id
    WHERE o.status = 'Delivered' AND oi.quantity > 0
    GROUP BY c.customer_id, c.name, c.email, c.segment
)
SELECT 
    ca.customer_id,
    ca.name,
    ca.email,
    ca.segment,
    ca.last_order_date,
    DATEDIFF(m.dataset_latest_date, ca.last_order_date) AS days_inactive,
    ca.total_orders_placed,
    ca.historical_spend,
    CASE 
        WHEN DATEDIFF(m.dataset_latest_date, ca.last_order_date) > 90 THEN 'CHURN RISK'
        ELSE 'ACTIVE'
    END AS customer_status
FROM CustomerActivity ca
CROSS JOIN MaxOrderDate m
WHERE DATEDIFF(m.dataset_latest_date, ca.last_order_date) > 90
ORDER BY ca.historical_spend DESC;


-- Query 6: Return Rates by Category
-- Measures return percentage = (returned items / delivered items) * 100
SELECT 
    p.category,
    COUNT(oi.order_item_id) AS total_delivered_items,
    COUNT(r.return_id) AS total_returned_items,
    ROUND((COUNT(r.return_id) / COUNT(oi.order_item_id)) * 100, 2) AS return_rate_pct
FROM OrderItems oi
JOIN Products p ON oi.product_id = p.product_id
JOIN Orders o ON oi.order_id = o.order_id
LEFT JOIN Returns r ON oi.order_item_id = r.order_item_id
WHERE o.status = 'Delivered' 
  AND oi.quantity > 0
GROUP BY p.category
ORDER BY return_rate_pct DESC;


-- Query 7: Top 5 Best-Selling Products by Revenue
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * p.sell_price * (1 - oi.discount_pct)), 2) AS total_revenue
FROM OrderItems oi
JOIN Products p ON oi.product_id = p.product_id
JOIN Orders o ON oi.order_id = o.order_id
WHERE o.status = 'Delivered' 
  AND oi.quantity > 0
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 5;
