-- Retail Sales Analysis SQL Project
-- Tool: MySQL Workbench
-- Dataset: Superstore Sales Dataset
-- Note: This SQL script is part of a portfolio project. 
-- To run it fully, users need to import the cleaned dataset into MySQL first.

-- =========================================================
-- 1. TABLE CREATION
-- =========================================================
-- Purpose:
-- Creates the main table structure used for the project.

CREATE TABLE superstore_sales (
	row_id INT,
	order_id TEXT,
	order_date TEXT,
    order_year INT,
    order_month TEXT,
    ship_date TEXT,
    ship_mode TEXT,
    customer_id TEXT,
    customer_name TEXT,
    segment TEXT,
    country TEXT,
    city TEXT,
    state TEXT,
    postal_code TEXT,
    region TEXT,
    product_id TEXT,
    category TEXT,
    sub_category TEXT,
    product_name TEXT,
    sales DOUBLE
);

-- =========================================================
-- 2. DATE CLEANING
-- =========================================================
-- Purpose:
-- Converts text-based date columns into proper DATE fields for analysis.

SELECT 
	STR_TO_DATE(order_date, ‘%d/%m/%Y’) AS converted_order_date,
	STR_TO_DATE(ship_date, ‘%d/%m/%Y’) AS converted_ship_date
FROM superstore_sales;

ALTER TABLE superstore_sales
	ADD COLUMN order_date_clean DATE,
	ADD COLUMN ship_date_clean DATE;
    
UPDATE superstore_sales
SET
    order_date_clean = STR_TO_DATE(order_date, '%d/%m/%Y'),
    ship_date_clean = STR_TO_DATE(ship_date, '%d/%m/%Y');

-- =========================================================
-- 3. QUERY 1: MONTHLY SALES TREND
-- =========================================================
-- Business Question:
-- How do sales change over time, and what is the month-over-month growth?
--
-- Insight:
-- This query helps identify seasonal patterns, strong sales periods,
-- and monthly growth or decline in revenue.

WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(order_date_clean, '%Y-%m-01') AS month_start,
        YEAR(order_date_clean) AS order_year,
        MONTH(order_date_clean) AS order_month_num,
        MONTHNAME(order_date_clean) AS order_month,
        ROUND(SUM(sales), 2) AS total_sales,
        COUNT(DISTINCT order_id) AS total_orders
    FROM superstore_sales
    GROUP BY
        DATE_FORMAT(order_date_clean, '%Y-%m-01'),
        YEAR(order_date_clean),
        MONTH(order_date_clean),
        MONTHNAME(order_date_clean)
)
SELECT
    month_start,
    order_year,
    order_month,
    total_sales,
    total_orders,
    ROUND(
        total_sales - LAG(total_sales) OVER (ORDER BY month_start),
        2
    ) AS previous_month_sales_difference,
    ROUND(
        (
            (total_sales - LAG(total_sales) OVER (ORDER BY month_start))
            / LAG(total_sales) OVER (ORDER BY month_start)
        ) * 100,
        2
    ) AS previous_month_sales_growth_pct
FROM monthly_sales
ORDER BY month_start;

-- =========================================================
-- 4. QUERY 2: SEGMENT SALES CONTRIBUTION
-- =========================================================
-- Business Question:
-- Which customer segments contribute the most to total sales?
--
-- Insight:
-- This query highlights which segment drives the most revenue,
-- helping businesses prioritise customer groups for targeting and retention.

WITH segment_sales AS 
(
	SELECT 
		segment,
        SUM(sales) AS total_sales,
        COUNT(DISTINCT order_id) AS total_orders
        FROM superstore_sales
        GROUP BY segment
)
	SELECT 
		segment,
        ROUND(total_sales) AS total_sales,
        total_orders,
        ROUND((total_sales/ SUM(total_sales) OVER() ) * 100, 2) AS segments_sales_perc,
        DENSE_RANK() OVER( ORDER BY total_sales DESC) AS segment_ranking
        FROM segment_sales 
        ORDER BY total_sales DESC;


-- =========================================================
-- 5. QUERY 3: CATEGORY AND SUB-CATEGORY PERFORMANCE
-- =========================================================
-- Business Question:
-- Which product categories and sub-categories generate the highest sales?
--
-- Insight:
-- This analysis helps identify the strongest-performing product areas
-- and supports merchandising and inventory decisions.

WITH categories_sales AS (
	SELECT
		category, sub_category,
        SUM(sales) AS total_sales,
        COUNT(DISTINCT order_id) AS total_orders
        FROM superstore_sales
        GROUP BY category, sub_category     
)
	SELECT 
		category, 
        sub_category, 
        ROUND(total_sales,2) AS total_sales, 
        total_orders,
        ROUND((total_sales / SUM(total_sales) OVER()) * 100,2) AS sales_contribution_perc,
        DENSE_RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
        from categories_sales
        ORDER BY sales_rank;

-- =========================================================
-- 6. QUERY 4: STATE SALES RANKING
-- =========================================================
-- Business Question:
-- Which states generate the highest sales and should be considered key markets?
--
-- Insight:
-- This query identifies top-performing states by revenue, orders,
-- and customer reach, helping support geographic growth strategy.

WITH state_sales AS (
	SELECT
		state,
        SUM(sales) AS total_sales,
        COUNT( DISTINCT order_id) AS total_orders,
        COUNT( DISTINCT customer_id) AS total_customers
        FROM superstore_sales
        GROUP BY state
)
	SELECT 
		state,
        ROUND(total_sales,2) AS total_sales,
        total_orders, total_customers,
        ROUND((total_sales / SUM(total_sales) OVER()) * 100,2) AS sales_contribution_perc,
        DENSE_RANK() OVER(ORDER BY total_sales DESC) AS state_ranking 
        FROM state_sales 
        ORDER BY state_ranking;


-- =========================================================
-- 7. QUERY 5: SHIPPING PERFORMANCE
-- =========================================================
-- Business Question:
-- Which shipping modes take the longest average time to deliver orders?
--
-- Insight:
-- This query evaluates operational efficiency by comparing delivery times
-- across ship modes and excluding invalid date records.


SELECT
	ship_mode,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(DATEDIFF(ship_date_clean, order_date_clean)),2) AS avg_shipping_days,
    MIN(DATEDIFF(ship_date_clean, order_date_clean)) AS fastest_delivery,
    MAX(DATEDIFF(ship_date_clean, order_date_clean)) AS slowest_delivery
    FROM superstore_sales
    WHERE ship_date_clean >= order_date_clean
    GROUP BY ship_mode
    ORDER BY avg_shipping_days DESC;

-- =========================================================
-- 8. QUERY 6: TOP PRODUCTS BY CATEGORY
-- =========================================================
-- Business Question:
-- Which are the top-selling products within each category?
--
-- Insight:
-- This query highlights the highest-revenue products in each category,
-- which can support product strategy and promotional planning.

WITH product_sales AS (
select 
	category,
	product_name,
    ROUND(SUM(sales),2) AS total_sales,
    COUNT(DISTINCT order_id) AS total_orders
    from superstore_sales
    GROUP BY category, product_name
), 
ranked_product AS(
	SELECT 
		category,
        product_name,
        total_sales,
        total_orders,
        ROW_NUMBER() OVER( PARTITION BY category ORDER BY total_sales DESC) AS product_rank 
        FROM product_sales
	)
    SELECT 
		category,
        product_name,
        total_sales,
        total_orders,
        product_rank 
        FROM ranked_product
        WHERE product_rank <=5
        ORDER BY category, product_rank;


-- =========================================================
-- 9. QUERY 7: AVERAGE ORDER VALUE BY SEGMENT
-- =========================================================
-- Business Question:
-- Which customer segments have the highest average order value?
--
-- Insight:
-- This analysis shows which segment places larger-value orders on average,
-- helping identify higher-value customer groups.

WITH customer_segment AS (
	SELECT
		segment,
        SUM(sales) AS total_sales,
        COUNT(DISTINCT order_id) AS total_orders
        FROM superstore_sales
        GROUP BY segment
) 
	SELECT 
		segment, 
        ROUND(total_sales,2) AS total_sales,
        total_orders,
        ROUND(total_sales/total_orders, 2) AS avg_order_value,
        DENSE_RANK() OVER(ORDER BY (total_sales/total_orders) DESC) AS aov_rank
        FROM customer_segment
        ORDER BY avg_order_value DESC;

-- =========================================================
-- 10. QUERY 8: TOP CUSTOMERS BY REVENUE
-- =========================================================
-- Business Question:
-- Which customers generate the most revenue for the business?
--
-- Insight:
-- This query identifies the highest-value customers by total sales,
-- supporting retention, loyalty, and account management strategy.

WITH customer_sales AS (
SELECT 
	customer_id,
    customer_name,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(sales) AS total_sales
    FROM superstore_sales
    GROUP BY customer_id, customer_name
)
	SELECT 
		customer_id,
        customer_name,
		total_orders,
        ROUND(total_sales,2) AS total_sales,
        ROUND((total_sales/total_orders),2) AS avg_order_value,
        DENSE_RANK() OVER(ORDER BY total_sales DESC) AS customer_ranking
        FROM customer_sales
        ORDER BY total_sales DESC
        LIMIT 10;

-- =========================================================
-- 11. QUERY 9: REGIONAL SALES ANALYSIS
-- =========================================================
-- Business Question:
-- What are the top-performing sales months within each region?
--
-- Insight:
-- This query identifies peak months by region, helping businesses understand
-- regional demand patterns and support local planning decisions.

WITH regional_sales AS (
	SELECT 
		region,
        DATE_FORMAT(order_date_clean, '%Y-%m-01') AS month_start,
        SUM(sales) AS total_sales
        FROM superstore_sales
        GROUP BY region, DATE_FORMAT(order_date_clean, '%Y-%m-01') 
), 
	ranked_sales AS(
		SELECT 
			region,
			month_start,
			ROUND(total_sales,2) AS total_sales,
			DENSE_RANK() OVER(PARTITION BY region ORDER BY total_sales DESC) AS month_rank
			FROM regional_sales
)
	SELECT
		region,
        month_start,
        total_sales,
        month_rank
        FROM ranked_sales
        WHERE month_rank <= 3
        ORDER BY region, month_rank;














