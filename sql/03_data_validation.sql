-- CAFE SALES DATA CLEANING | 03 DATA VALIDATION
USE cafe_sales;

-- 1. Verify original and final record counts match.
SELECT
  (SELECT COUNT(*) FROM cafe_sales_raw) AS original_records,
  (SELECT COUNT(*) FROM cafe_sales_cleaned) AS cleaned_records;

-- 2. Detect duplicate or NULL transaction IDs.
SELECT `Transaction ID`, COUNT(*) AS occurrence_count
FROM cafe_sales_cleaned
GROUP BY `Transaction ID`
HAVING COUNT(*) > 1;
SELECT COUNT(*) AS missing_ids FROM cafe_sales_cleaned
WHERE `Transaction ID` IS NULL;

-- 3. Verify ID length and expected format.
SELECT COUNT(*) AS invalid_ids 
FROM cafe_sales_cleaned
WHERE LENGTH(`Transaction ID`) <> 11 OR `Transaction ID` NOT REGEXP '^TXN_[0-9]{7}$';

-- 4. Verify every original ID is present in the final table.
SELECT r.`Transaction ID` AS missing_from_final
FROM cafe_sales_raw AS r
LEFT JOIN cafe_sales_cleaned AS c
  ON r.`Transaction ID` = c.`Transaction ID`
WHERE c.`Transaction ID` IS NULL;

-- 5. Count unresolved NULLs by column.
SELECT
  SUM(Item IS NULL) AS missing_item,
  SUM(Quantity IS NULL) AS missing_quantity,
  SUM(`Price Per Unit` IS NULL) AS missing_unit_price,
  SUM(`Total Spent` IS NULL) AS missing_total_spent,
  SUM(`Payment Method` IS NULL) AS missing_payment_method,
  SUM(Location IS NULL) AS missing_location,
  SUM(`Transaction Date` IS NULL) AS missing_transaction_date
FROM cafe_sales_cleaned;

-- 6. Validate financial relationships on complete rows.
SELECT COUNT(*) AS inconsistent_financial_rows
FROM cafe_sales_cleaned
WHERE Quantity IS NOT NULL
  AND `Price Per Unit` IS NOT NULL
  AND `Total Spent` IS NOT NULL
  AND `Total Spent` <> Quantity * `Price Per Unit`;

-- 7. Verify remaining missing item names by unit price.
SELECT `Price Per Unit`, COUNT(*) AS missing_item_count
FROM cafe_sales_cleaned
WHERE Item IS NULL
GROUP BY `Price Per Unit`
ORDER BY `Price Per Unit`;

-- 8. Profile valid categorical values, including NULL groups.
SELECT `Payment Method`, COUNT(*) AS total_transactions
FROM cafe_sales_cleaned
GROUP BY `Payment Method`
ORDER BY total_transactions DESC;

SELECT Location, COUNT(*) AS total_transactions
FROM cafe_sales_cleaned
GROUP BY Location
ORDER BY total_transactions DESC;

-- 9. Date coverage and monthly distribution.
SELECT MIN(`Transaction Date`) AS earliest_date,
       MAX(`Transaction Date`) AS latest_date
FROM cafe_sales_cleaned;
SELECT MONTH(`Transaction Date`) AS transaction_month,
       COUNT(*) AS total_transactions
FROM cafe_sales_cleaned
WHERE `Transaction Date` IS NOT NULL
GROUP BY transaction_month
ORDER BY transaction_month ASC;

-- 10. Inspect the final column definitions and primary key.
DESCRIBE cafe_sales_cleaned;

-- OBSERVED VALIDATION FINDINGS:
-- 10,000 original and cleaned rows; zero duplicate IDs; zero missing IDs;
-- zero original IDs absent from final; zero financial mismatches on complete rows.
-- Remaining NULLs: Item 480; Quantity 23; Price Per Unit 6;
-- Total Spent 23; Payment Method 3,178; Location 3,961;

