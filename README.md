# Café Sales Data Cleaning & Quality Validation | MySQL
  
**Dataset:** 10,000 café transactions, 8 columns  
**Focus:** Data profiling, missing-value recovery, type conversion, integrity checks

## Project Overview

This project demonstrates an end-to-end SQL data-cleaning and validation workflow using a café sales transaction dataset originally obtained from Kaggle. The imported data contained missing information, invalid placeholders (`ERROR`, `UNKNOWN`, and blanks), and text-based fields that needed more suitable data types.

I investigated the data-quality issues, standardized invalid values, recovered missing information where supported by transaction mathematics or reliable product-price relationships, and validated the resulting table. **All 10,000 transactions were preserved.** I retained genuinely unrecoverable values as `NULL` instead of fabricating information.

### Objectives

- Profile the original dataset and identify invalid and missing values.
- Preserve the original import while cleaning a separate working copy.
- Convert quantity, price, total, and date fields to appropriate SQL types.
- Recover values only when supported by defensible business rules.
- Validate transaction IDs, financial consistency, and date integrity.
- Export a cleaned dataset for subsequent analysis and visualization.

## Data Quality Assessment

The raw dataset contains eight fields: `Transaction ID`, `Item`, `Quantity`, `Price Per Unit`, `Total Spent`, `Payment Method`, `Location`, and `Transaction Date`. All fields were initially imported as text.

| Column | Initially missing or invalid | % of 10,000 rows |
|---|---:|---:|
| Item | 969 | 9.69% |
| Quantity | 479 | 4.79% |
| Price Per Unit | 533 | 5.33% |
| Total Spent | 502 | 5.02% |
| Payment Method | 3,178 | 31.78% |
| Location | 3,961 | 39.61% |
| Transaction Date | 460 | 4.60% |

*These counts refer to fields, not unique transactions; a transaction can have multiple missing fields.*

I used `COUNT`, `DISTINCT`, `GROUP BY`, `REGEXP`, and conditional expressions to inspect values and assess the scope of cleaning. All 10,000 transaction IDs were unique and followed the `TXN_` plus seven digits pattern.

## Data Cleaning Methodology

### 1. Preserve the original records

I created a separate working table, leaving `cafe_sales_raw` untouched:

```sql
CREATE TABLE cafe_sales_cleaning_copy AS
SELECT * FROM cafe_sales_raw;
```

### 2. Normalize missing-value placeholders

I converted blank strings, `ERROR`, and `UNKNOWN` to SQL `NULL` across affected fields. For example:

```sql
UPDATE cafe_sales_cleaning_copy
SET Item = NULL
WHERE UPPER(TRIM(COALESCE(Item, ''))) IN ('', 'ERROR', 'UNKNOWN');
```

### 3. Validate and convert data types

Before conversion, I checked numeric strings and validated date formats and calendar days. I then converted `Quantity` to `INT`, `Price Per Unit` and `Total Spent` to `DECIMAL(10,2)`, and `Transaction Date` to `DATE`. The final `Transaction ID` field is `VARCHAR(11) NOT NULL PRIMARY KEY`.

### 4. Recover missing unit prices

Where valid, unit prices can be inferred from `Total Spent / Quantity`. I cross-checked inferred prices against known product prices, used established single-price mappings for known items, and accepted observed café price points for eligible records with unknown item names. **527 of 533 missing prices were recovered.**

### 5. Recover missing quantities

I inferred quantity from `Total Spent / Price Per Unit` only when the result was a positive whole number.

```sql
UPDATE cafe_sales_cleaning_copy
SET Quantity = `Total Spent` / `Price Per Unit`
WHERE Quantity IS NULL
  AND `Total Spent` > 0
  AND `Price Per Unit` > 0
  AND `Total Spent` / `Price Per Unit` = FLOOR(`Total Spent` / `Price Per Unit`);
```

**456 of 479 missing quantities were recovered.**

### 6. Recover missing totals

For transactions with known quantity and unit price, I calculated `Total Spent = Quantity × Price Per Unit`. **479 of 502 missing totals were recovered.**

### 7. Recover identifiable item names

I used unique product-price relationships to infer item names:

| Unit price | Identifiable item |
|---:|---|
| $1.00 | Cookie |
| $1.50 | Tea |
| $2.00 | Coffee |
| $5.00 | Salad |

A `CASE` expression recovered **489 of 969 missing item names**. I did **not** assign an item at $3.00 (Cake or Juice) or $4.00 (Sandwich or Smoothie), because those prices are shared by multiple products.

### 8. Retain unresolved values

Unrecoverable item names, financial fields, payment methods, locations, and dates remain `NULL`. This avoids introducing unsupported assumptions into future reporting.

## Results: Before and After

| Field | Initially missing | Recovered | Remaining missing | Recovery rate |
|---|---:|---:|---:|---:|
| Price Per Unit | 533 | 527 | 6 | 98.87% |
| Quantity | 479 | 456 | 23 | 95.20% |
| Total Spent | 502 | 479 | 23 | 95.42% |
| Item | 969 | 489 | 480 | 50.46% |
| **Total across these fields** | **2,483** | **1,951** | **532** | **78.57%** |

The **1,951 recovered values** are field-level recoveries, not 1,951 distinct transactions. Payment method (3,178 missing), location (3,961 missing), and transaction date (460 missing) were not imputed without reliable evidence.

## Data Validation and Quality Assurance

I checked the final table for record preservation, transaction ID integrity, valid dates, and financial consistency.

### Record preservation

```sql
SELECT 'Original' AS dataset, COUNT(*) AS total_records FROM cafe_sales_raw
UNION ALL
SELECT 'Cleaned' AS dataset, COUNT(*) AS total_records FROM cafe_sales_cleaned;
```

**Result:** 10,000 original rows and 10,000 final rows. A `LEFT JOIN` check also confirmed that no original transaction IDs were missing from the cleaned table.

### Transaction ID integrity

```sql
SELECT `Transaction ID`, COUNT(*) AS duplicate_count
FROM cafe_sales_cleaned
GROUP BY `Transaction ID`
HAVING COUNT(*) > 1;
```

**Result:** No duplicate, missing, or incorrectly formatted transaction IDs. The final table uses `Transaction ID` as its primary key.

### Financial consistency

```sql
SELECT COUNT(*) AS inconsistent_transactions
FROM cafe_sales_cleaned
WHERE Quantity IS NOT NULL
  AND `Price Per Unit` IS NOT NULL
  AND `Total Spent` IS NOT NULL
  AND `Total Spent` <> ROUND(Quantity * `Price Per Unit`, 2);
```

**Result:** Zero inconsistencies among transactions with complete financial values.

### Date and schema checks

The available valid dates span **2023-01-01 through 2023-12-31**. There are **9,540 dated transactions** and **460 transactions with missing dates**. Calendar-validity checks were performed before conversion. The final schema was inspected with `DESCRIBE cafe_sales_cleaned`.

| Validation check | Observed result |
|---|---|
| Original transactions retained | 10,000 / 10,000 |
| Duplicate transaction IDs | 0 |
| Invalid transaction ID formats | 0 |
| Missing original IDs in final table | 0 |
| Financial mismatches among complete records | 0 |
| Primary key | `Transaction ID` |




## Limitations and Next Steps

The cleaned dataset still contains unresolved missing values. Analysis involving payment method, location, item, or transaction date should account for missingness rather than treating the remaining records as complete. A future extension will use Python to profile the exported data, build charts, and explore sales trends without inventing missing information.

## Skills Demonstrated

**SQL data profiling · Conditional logic (`CASE`) · Aggregation · Regular expressions · `JOIN` validation · Missing-value recovery · Data-type conversion · Primary keys · Data-quality assurance · Documentation**
