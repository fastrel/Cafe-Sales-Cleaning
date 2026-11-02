-- CAFE SALES DATA CLEANING | 02 DATA CLEANING
-- CAUTION: This script creates/replaces working and final tables.
-- The original cafe_sales_raw table is never updated.
USE cafe_sales;

-- 1. Create a working copy of the original TEXT-based import.
-- SAFETY: Do not run this script on your existing completed tables.
-- It is a rebuild script for a fresh schema/backup. The following DROP
-- statements replace prior work and must be deliberately authorized.
DROP TABLE IF EXISTS cafe_sales_cleaned;
DROP TABLE IF EXISTS cafe_sales_cleaning_copy;
CREATE TABLE cafe_sales_cleaning_copy AS
SELECT * FROM cafe_sales_raw;

-- 2. Normalize missing/invalid placeholders to SQL NULL.
-- Handles blank/whitespace, ERROR, and UNKNOWN. Preserve genuine values.
UPDATE cafe_sales_cleaning_copy
SET Item = CASE WHEN UPPER(TRIM(COALESCE(Item,''))) IN ('','ERROR','UNKNOWN') THEN NULL ELSE TRIM(Item) END,
    Quantity = CASE WHEN UPPER(TRIM(COALESCE(Quantity,''))) IN ('','ERROR','UNKNOWN') THEN NULL ELSE TRIM(Quantity) END,
    `Price Per Unit` = CASE WHEN UPPER(TRIM(COALESCE(`Price Per Unit`,''))) IN ('','ERROR','UNKNOWN') THEN NULL ELSE TRIM(`Price Per Unit`) END,
    `Total Spent` = CASE WHEN UPPER(TRIM(COALESCE(`Total Spent`,''))) IN ('','ERROR','UNKNOWN') THEN NULL ELSE TRIM(`Total Spent`) END,
    `Payment Method` = CASE WHEN UPPER(TRIM(COALESCE(`Payment Method`,''))) IN ('','ERROR','UNKNOWN') THEN NULL ELSE TRIM(`Payment Method`) END,
    Location = CASE WHEN UPPER(TRIM(COALESCE(Location,''))) IN ('','ERROR','UNKNOWN') THEN NULL ELSE TRIM(Location) END,
    `Transaction Date` = CASE WHEN UPPER(TRIM(COALESCE(`Transaction Date`,''))) IN ('','ERROR','UNKNOWN') THEN NULL ELSE TRIM(`Transaction Date`) END;

-- 3. Confirm numeric values are convertible BEFORE changing types.
-- These SELECTs should return zero. Stop and investigate if nonzero.
SELECT COUNT(*) AS bad_quantities 
FROM cafe_sales_cleaning_copy
WHERE Quantity IS NOT NULL AND Quantity NOT REGEXP '^[0-9]+$';

SELECT COUNT(*) AS bad_prices 
FROM cafe_sales_cleaning_copy
WHERE `Price Per Unit` IS NOT NULL AND `Price Per Unit` NOT REGEXP '^[0-9]+(\\.[0-9]+)?$';

SELECT COUNT(*) AS bad_totals 
FROM cafe_sales_cleaning_copy
WHERE `Total Spent` IS NOT NULL AND `Total Spent` NOT REGEXP '^[0-9]+(\\.[0-9]+)?$';

-- 4. Validate date text BEFORE conversion. Stop if this returns any rows.
-- Check syntax and calendar validity separately, avoiding implicit bad casts.
SELECT `Transaction ID`, `Transaction Date`
FROM cafe_sales_cleaning_copy
WHERE `Transaction Date` IS NOT NULL
  AND (`Transaction Date` NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
       OR SUBSTRING(`Transaction Date`,6,2) NOT BETWEEN '01' AND '12'
       OR SUBSTRING(`Transaction Date`,9,2) NOT BETWEEN '01' AND '31');
-- Validate actual calendar days, including leap-year February.
-- Run only after the syntax/month checks above return no rows.
SELECT `Transaction ID`, `Transaction Date`
FROM cafe_sales_cleaning_copy
WHERE `Transaction Date` IS NOT NULL
  AND CAST(SUBSTRING(`Transaction Date`, 9, 2) AS UNSIGNED)
      > DAYOFMONTH(LAST_DAY(CONCAT(SUBSTRING(`Transaction Date`,1,7),'-01')));

-- Verify no date strings fail conversion.
SELECT COUNT(*) AS failed_date_conversions
FROM cafe_sales_cleaning_copy
WHERE `Transaction Date` IS NOT NULL
  AND STR_TO_DATE(`Transaction Date`, '%Y-%m-%d') IS NULL;
-- All three date checks should be empty/zero before ALTER TABLE.

-- 5. Convert numeric/date types (performed only after checks above pass).
ALTER TABLE cafe_sales_cleaning_copy
  MODIFY COLUMN Quantity INT NULL,
  MODIFY COLUMN `Price Per Unit` DECIMAL(10,2) NULL,
  MODIFY COLUMN `Total Spent` DECIMAL(10,2) NULL,
  MODIFY COLUMN `Transaction Date` DATE NULL;

-- 6. Establish observed item-to-price mapping from valid records.
DROP TEMPORARY TABLE IF EXISTS known_prices;
CREATE TEMPORARY TABLE known_prices AS
SELECT Item, MAX(`Price Per Unit`) AS known_price
FROM cafe_sales_cleaning_copy
WHERE Item IS NOT NULL AND `Price Per Unit` IS NOT NULL
GROUP BY Item
HAVING COUNT(DISTINCT `Price Per Unit`) = 1;

-- 7. Recover missing unit prices only when implied price matches known item price.
-- In the walkthrough, 447 rows passed this cross-check.
UPDATE cafe_sales_cleaning_copy AS c
JOIN known_prices AS kp ON c.Item = kp.Item
SET c.`Price Per Unit` = c.`Total Spent` / c.Quantity
WHERE c.`Price Per Unit` IS NULL
  AND c.`Total Spent` IS NOT NULL
  AND c.Quantity > 0
  AND c.`Total Spent` / c.Quantity = kp.known_price;

-- 8. Recover unit prices for remaining known-item rows, using the
-- previously validated single price per item. In the walkthrough,
-- this accounted for 32 additional rows.
UPDATE cafe_sales_cleaning_copy AS c
JOIN known_prices AS kp ON c.Item = kp.Item
SET c.`Price Per Unit` = kp.known_price
WHERE c.`Price Per Unit` IS NULL;

-- 9. Recover additional unit prices for rows with unknown item but valid
-- observed café price points. The item name itself stays NULL.
UPDATE cafe_sales_cleaning_copy
SET `Price Per Unit` = `Total Spent` / Quantity
WHERE Item IS NULL
  AND `Price Per Unit` IS NULL
  AND `Total Spent` IS NOT NULL
  AND Quantity > 0
  AND `Total Spent` / Quantity IN (1.00,1.50,2.00,3.00,4.00,5.00);

-- 10. Recover missing quantities where total/price gives a positive integer.
-- In the walkthrough, 456 rows were recovered.
UPDATE cafe_sales_cleaning_copy
SET Quantity = `Total Spent` / `Price Per Unit`
WHERE Quantity IS NULL
  AND `Total Spent` > 0
  AND `Price Per Unit` > 0
  AND `Total Spent` / `Price Per Unit` = FLOOR(`Total Spent` / `Price Per Unit`);

-- 11. Recover missing total spend using quantity * unit price.
-- In the walkthrough, 479 rows were recovered.
UPDATE cafe_sales_cleaning_copy
SET `Total Spent` = Quantity * `Price Per Unit`
WHERE `Total Spent` IS NULL
  AND Quantity > 0
  AND `Price Per Unit` > 0;

-- 12. Recover item names only for UNIQUE price-to-item mappings.
-- In the walkthrough, 489 rows were recovered.
-- Do NOT infer Cake vs Juice at $3, or Sandwich vs Smoothie at $4.
UPDATE cafe_sales_cleaning_copy
SET Item = CASE
  WHEN `Price Per Unit` = 1.00 THEN 'Cookie'
  WHEN `Price Per Unit` = 1.50 THEN 'Tea'
  WHEN `Price Per Unit` = 2.00 THEN 'Coffee'
  WHEN `Price Per Unit` = 5.00 THEN 'Salad'
  ELSE Item
END
WHERE Item IS NULL AND `Price Per Unit` IN (1.00,1.50,2.00,5.00);

-- 13. Preserve unknown payment method, location, date and ambiguous item as NULL.
-- No fabricated values are inserted.

-- 14. Create the final deliverable table and enforce transaction uniqueness.
CREATE TABLE cafe_sales_cleaned AS
SELECT * FROM cafe_sales_cleaning_copy;
ALTER TABLE cafe_sales_cleaned
  MODIFY COLUMN `Transaction ID` VARCHAR(11) NOT NULL;
ALTER TABLE cafe_sales_cleaned
  ADD PRIMARY KEY (`Transaction ID`);

-- 15. Confirm output.
SELECT COUNT(*) AS cleaned_records FROM cafe_sales_cleaned;
DESCRIBE cafe_sales_cleaned;


