-- CAFE SALES DATA CLEANING | 01 DATA EXPLORATION
USE cafe_sales;

-- 1. Review source structure and sample records.
DESCRIBE cafe_sales_raw;
SELECT * 
FROM cafe_sales_raw LIMIT 10;

-- 2. Count original records and unique transaction IDs.
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT `Transaction ID`) AS distinct_transaction_ids
FROM cafe_sales_raw;

-- 3. Check IDs with unexpected format (TXN_ followed by 7 digits).
SELECT COUNT(*) AS invalid_transaction_ids
FROM cafe_sales_raw
WHERE `Transaction ID` IS NULL OR `Transaction ID` NOT REGEXP '^TXN_[0-9]{7}$';

-- 4. Explore distinct values and dirty tokens in categorical fields.
SELECT DISTINCT Item 
FROM cafe_sales_raw 
ORDER BY Item;

SELECT DISTINCT `Payment Method` 
FROM cafe_sales_raw 
ORDER BY `Payment Method`;

SELECT DISTINCT Location 
FROM cafe_sales_raw 
ORDER BY Location;

-- 5. Explore distinct tokens in numeric/date fields (raw import was TEXT).
SELECT DISTINCT Quantity 
FROM cafe_sales_raw 
ORDER BY Quantity;

SELECT DISTINCT `Price Per Unit` 
FROM cafe_sales_raw 
ORDER BY `Price Per Unit`;

SELECT DISTINCT `Total Spent` 
FROM cafe_sales_raw 
ORDER BY `Total Spent`;

SELECT DISTINCT `Transaction Date` 
FROM cafe_sales_raw 
ORDER BY `Transaction Date`;

-- 6. Count missing/placeholder entries before cleaning.
-- TRIM handles whitespace-only strings. NULLIF converts blanks to NULL for counting.
-- The source used blanks, ERROR, and UNKNOWN as missing-data markers.
SELECT
  SUM(CASE WHEN UPPER(TRIM(COALESCE(Item,''))) IN ('','ERROR','UNKNOWN') THEN 1 ELSE 0 END) AS item_missing,
  SUM(CASE WHEN UPPER(TRIM(COALESCE(Quantity,''))) IN ('','ERROR','UNKNOWN') THEN 1 ELSE 0 END) AS quantity_missing,
  SUM(CASE WHEN UPPER(TRIM(COALESCE(`Price Per Unit`,''))) IN ('','ERROR','UNKNOWN') THEN 1 ELSE 0 END) AS price_missing,
  SUM(CASE WHEN UPPER(TRIM(COALESCE(`Total Spent`,''))) IN ('','ERROR','UNKNOWN') THEN 1 ELSE 0 END) AS total_missing,
  SUM(CASE WHEN UPPER(TRIM(COALESCE(`Payment Method`,''))) IN ('','ERROR','UNKNOWN') THEN 1 ELSE 0 END) AS payment_missing,
  SUM(CASE WHEN UPPER(TRIM(COALESCE(Location,''))) IN ('','ERROR','UNKNOWN') THEN 1 ELSE 0 END) AS location_missing,
  SUM(CASE WHEN UPPER(TRIM(COALESCE(`Transaction Date`,''))) IN ('','ERROR','UNKNOWN') THEN 1 ELSE 0 END) AS date_missing
FROM cafe_sales_raw;

-- 7. Examine potential duplicate transaction IDs.
SELECT `Transaction ID`, COUNT(*) AS occurrences
FROM cafe_sales_raw
GROUP BY `Transaction ID`
HAVING COUNT(*) > 1;

-- OBSERVED PROJECT FINDINGS (from the cleaning walkthrough):
-- Original rows: 10,000; distinct transaction IDs: 10,000.
-- Initial missing/placeholder counts: Item 969; Quantity 479;
-- Price Per Unit 533; Total Spent 502; Payment Method 3,178;
-- Location 3,961; Transaction Date 460.
