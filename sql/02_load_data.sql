-- Capstone Project: Data Loading Script (LOAD DATA INFILE)
-- Author: Rudhiyansh Sandanshiv

USE capstone;

-- Drop unique constraint on email for initial messy data staging
ALTER TABLE Customers DROP INDEX IF EXISTS email;

-- Disable key checks temporarily for faster bulk loading
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;

-- Reset tables before loading
TRUNCATE TABLE Region;
TRUNCATE TABLE Products;
TRUNCATE TABLE Customers;
TRUNCATE TABLE Orders;
TRUNCATE TABLE OrderItems;
TRUNCATE TABLE Returns;

-- 1. Load Regions (5 rows)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/regions_raw.csv'
INTO TABLE Region
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(region_id, region_name, country);

-- 2. Load Products (15 rows)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/products_raw.csv'
INTO TABLE Products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(product_id, product_name, category, cost_price, sell_price);

-- 3. Load Customers (5,050 rows)
-- Handles empty/missing region values with NULLIF
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers_raw.csv'
INTO TABLE Customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(customer_id, name, email, signup_date, @v_reg, segment)
SET region_id = NULLIF(NULLIF(@v_reg, ''), 'NaN');

-- 4. Load Orders (20,000 rows)
-- Converts mixed date formats (DD/MM/YYYY and YYYY-MM-DD) to MySQL DATE format
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/orders_raw.csv'
INTO TABLE Orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(order_id, customer_id, @v_date, status)
SET order_date = CASE 
    WHEN @v_date LIKE '%/%' THEN STR_TO_DATE(@v_date, '%d/%m/%Y')
    ELSE STR_TO_DATE(@v_date, '%Y-%m-%d')
END;

-- 5. Load OrderItems (36,378 rows)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/order_items_raw.csv'
INTO TABLE OrderItems
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(order_item_id, order_id, product_id, quantity, discount_pct);

-- 6. Load Returns (1,231 rows)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/returns_raw.csv'
INTO TABLE Returns
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(return_id, order_item_id, return_date, reason);

-- Re-enable constraints
SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS = 1;

-- Verify row counts across all tables
SELECT 'Region' AS Table_Name, COUNT(*) AS Total_Rows FROM Region
UNION ALL
SELECT 'Products', COUNT(*) FROM Products
UNION ALL
SELECT 'Customers', COUNT(*) FROM Customers
UNION ALL
SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL
SELECT 'OrderItems', COUNT(*) FROM OrderItems
UNION ALL
SELECT 'Returns', COUNT(*) FROM Returns;
