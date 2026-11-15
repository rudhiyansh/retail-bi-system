-- Capstone Project: Retail Business Intelligence System
-- Database Schema (3NF Relational Model)
-- Author: Rudhiyansh Sandanshiv

CREATE DATABASE IF NOT EXISTS capstone;
USE capstone;

-- 1. Region table
CREATE TABLE Region (
    region_id INT PRIMARY KEY,
    region_name VARCHAR(50) NOT NULL,
    country VARCHAR(50) DEFAULT 'India'
);

-- 2. Customers table
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    signup_date DATE,
    region_id INT,
    segment VARCHAR(50),
    FOREIGN KEY (region_id) REFERENCES Region(region_id)
);

-- 3. Products table
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    cost_price DECIMAL(10, 2),
    sell_price DECIMAL(10, 2)
);

-- 4. Orders table
CREATE TABLE Orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    status VARCHAR(50),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

-- 5. OrderItems table
CREATE TABLE OrderItems (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    discount_pct DECIMAL(4, 2),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- 6. Returns table
CREATE TABLE Returns (
    return_id INT PRIMARY KEY,
    order_item_id INT,
    return_date DATE,
    reason VARCHAR(100),
    FOREIGN KEY (order_item_id) REFERENCES OrderItems(order_item_id)
);
