/*03_promo_analysis.sql
Business question: do promotions pay off, and what makes them work better?
A. Product-week table
B. Promo lift: promoted weeks vs each product's own no-discount weeks
C. Robustness checks on the lift
D. Promo payback: how many extra units, and what discount per extra unit
E. Display and mailer support
Uses the cat_tx view from 02_category_snapshot.sql.
This file re-creates its helper tables (DROP IF EXISTS), so it can be re-run, but the causal_cat step takes a few minutes.
Queries marked EXPORT are saved as CSV from the result grid for Power BI.*/

USE dunnhumby;

/*A. Product-week table
Retailers set promotions per product per week, so this is the natural unit.
It lets each product be compared with ITS OWN no-discount weeks.*/
DROP TABLE IF EXISTS pw;
CREATE TABLE pw AS
SELECT product_id, week_no, SUM(quantity) units, SUM(disc) disc, SUM(shelf_total) shelf,
       COUNT(DISTINCT household_key) hh
FROM cat_tx GROUP BY product_id, week_no;

/*Check: are there enough zero-discount weeks to use as a baseline?
(Result: about 14,000 product-weeks with zero discount, so yes.)*/
SELECT CASE WHEN disc/shelf < 0.0001 THEN 'a: zero' WHEN disc/shelf < 0.02 THEN 'b: <2%'
            WHEN disc/shelf < 0.05 THEN 'c: 2-5%' WHEN disc/shelf < 0.1 THEN 'd: 5-10%'
            ELSE 'e: 10%+' END AS bucket,
       COUNT(*) product_weeks, COUNT(DISTINCT product_id) products
FROM pw GROUP BY bucket ORDER BY bucket;

/*B. Promo lift (main result)
Baseline = a product's average weekly units in weeks with no discount (only products with at least 10 such weeks).
Lift index = units in promoted weeks / baseline units (2.0 = twice normal volume).
EXPORT -> 05_promo_lift.csv*/
WITH b AS (
  SELECT *, CASE WHEN disc/shelf < 0.0001 THEN '0 No promo'
                 WHEN disc/shelf < 0.1 THEN '1 0-10%'
                 WHEN disc/shelf < 0.2 THEN '2 10-20%'
                 WHEN disc/shelf < 0.3 THEN '3 20-30%'
                 WHEN disc/shelf < 0.4 THEN '4 30-40%'
                 ELSE '5 40%+' END AS bucket
  FROM pw),
base AS (SELECT product_id, AVG(units) base_units
         FROM b WHERE bucket = '0 No promo'
         GROUP BY product_id HAVING COUNT(*) >= 10)
SELECT bucket, COUNT(*) product_weeks, COUNT(DISTINCT product_id) products,
       ROUND(SUM(units)/SUM(base_units),2) lift_index
FROM b JOIN base USING (product_id)
GROUP BY bucket ORDER BY bucket;

/*C. Robustness checks on the lift
C1. Exclude slow-selling products (baseline under 5 units a week).
Result: same pattern (flat below 20%, steep from 30%).*/
WITH b AS (
  SELECT *, CASE WHEN disc/shelf < 0.0001 THEN '0 No promo'
                 WHEN disc/shelf < 0.1 THEN '1 0-10%'
                 WHEN disc/shelf < 0.2 THEN '2 10-20%'
                 WHEN disc/shelf < 0.3 THEN '3 20-30%'
                 WHEN disc/shelf < 0.4 THEN '4 30-40%'
                 ELSE '5 40%+' END AS bucket
  FROM pw),
base AS (SELECT product_id, AVG(units) base_units
         FROM b WHERE bucket = '0 No promo'
         GROUP BY product_id HAVING COUNT(*) >= 10 AND AVG(units) >= 5)
SELECT bucket, COUNT(*) product_weeks, COUNT(DISTINCT product_id) products,
       ROUND(SUM(units)/SUM(base_units),2) lift_index
FROM b JOIN base USING (product_id)
GROUP BY bucket ORDER BY bucket;

/*C2. Exclude weeks 1-14 (fewer active households in the early weeks).
Result: same pattern; deep-discount lift is, if anything, higher.*/
WITH b AS (
  SELECT *, CASE WHEN disc/shelf < 0.0001 THEN '0 No promo'
                 WHEN disc/shelf < 0.1 THEN '1 0-10%'
                 WHEN disc/shelf < 0.2 THEN '2 10-20%'
                 WHEN disc/shelf < 0.3 THEN '3 20-30%'
                 WHEN disc/shelf < 0.4 THEN '4 30-40%'
                 ELSE '5 40%+' END AS bucket
  FROM pw WHERE week_no >= 15),
base AS (SELECT product_id, AVG(units) base_units
         FROM b WHERE bucket = '0 No promo'
         GROUP BY product_id HAVING COUNT(*) >= 10)
SELECT bucket, COUNT(*) product_weeks, COUNT(DISTINCT product_id) products,
       ROUND(SUM(units)/SUM(base_units),2) lift_index
FROM b JOIN base USING (product_id)
GROUP BY bucket ORDER BY bucket;

/*D. Promo payback
incremental_units = units above the product's no-discount baseline
pct_incremental   = share of promo-week units that were extra
discount_per_incremental_unit = dollars of discount paid per extra unit
Note: no margin data, so this is a cost per extra unit, not profit.
EXPORT -> 06_promo_payback.csv*/
WITH b AS (
  SELECT *, CASE WHEN disc/shelf < 0.0001 THEN '0 No promo' WHEN disc/shelf < 0.1 THEN '1 0-10%'
                 WHEN disc/shelf < 0.2 THEN '2 10-20%' WHEN disc/shelf < 0.3 THEN '3 20-30%'
                 ELSE '4 30%+' END AS bucket FROM pw),
base AS (SELECT product_id, AVG(units) base_units FROM b
         WHERE bucket = '0 No promo' GROUP BY product_id HAVING COUNT(*) >= 10)
SELECT bucket, SUM(units) units,
       ROUND(SUM(units - base_units)) incremental_units,
       ROUND(100*SUM(units - base_units)/SUM(units),1) pct_incremental,
       ROUND(SUM(disc)) discount_spent,
       ROUND(SUM(disc)/NULLIF(SUM(units - base_units),0),2) discount_per_incremental_unit
FROM b JOIN base USING (product_id)
WHERE bucket <> '0 No promo'
GROUP BY bucket ORDER BY bucket;

/*Scale for the payback figures: average shelf price per unit (about $2.71)*/
SELECT ROUND(SUM(shelf_total)/SUM(quantity),2) avg_shelf_price_per_unit FROM cat_tx;

/*E. Display and mailer support
E1. Reduce the very large causal_data table to soft drinks products.
DISTINCT removes duplicate rows; REPLACE(... CHAR(13) ...) strips stray carriage returns left over from Windows line endings.*/
DROP TABLE IF EXISTS causal_cat;
CREATE TABLE causal_cat AS
SELECT DISTINCT c.product_id, c.store_id, c.week_no,
       TRIM(REPLACE(c.display, CHAR(13), '')) AS display,
       TRIM(REPLACE(c.mailer,  CHAR(13), '')) AS mailer
FROM causal_data c
JOIN (SELECT DISTINCT product_id FROM cat_tx) p ON c.product_id = p.product_id;

CREATE INDEX ic ON causal_cat(product_id, store_id, week_no);

/*Checks. Expect a small gap between rows (2,179,722) and distinct keys (2,177,116):
a few product-store-weeks have two records (e.g. two mailer placements).*/
SELECT COUNT(*) total_rows, COUNT(DISTINCT product_id, store_id, week_no) distinct_keys FROM causal_cat;
SELECT display, COUNT(*) n FROM causal_cat GROUP BY display;
SELECT mailer,  COUNT(*) n FROM causal_cat GROUP BY mailer;

/*E2. Collapse to one row per product-store-week with yes/no flags ('0' means no display / no mailer; any other code is some placement).*/
DROP TABLE IF EXISTS causal_flags;
CREATE TABLE causal_flags AS
SELECT product_id, store_id, week_no,
       MAX(display <> '0') AS on_display,
       MAX(mailer  <> '0') AS on_mailer
FROM causal_cat
GROUP BY product_id, store_id, week_no;

CREATE INDEX icf ON causal_flags(product_id, store_id, week_no);

SELECT COUNT(*) FROM causal_flags;   -- expect 2,177,116

/*E3. Product-store-week sales table, with the display/mailer flags attached.
Weeks with no record in the causal file are treated as "no display, no mailer".*/
DROP TABLE IF EXISTS psw;
CREATE TABLE psw AS
SELECT product_id, store_id, week_no, SUM(quantity) units,
       SUM(disc) disc, SUM(shelf_total) shelf
FROM cat_tx GROUP BY product_id, store_id, week_no;

/*Coverage: only about a third of soft drinks product-store-weeks have a causal record.*/
SELECT COUNT(*) total, SUM(f.product_id IS NOT NULL) matched
FROM psw s LEFT JOIN causal_flags f
  ON f.product_id = s.product_id AND f.store_id = s.store_id AND f.week_no = s.week_no;

DROP TABLE IF EXISTS psw2;
CREATE TABLE psw2 AS
SELECT s.*, COALESCE(f.on_display, 0) AS on_display, COALESCE(f.on_mailer, 0) AS on_mailer
FROM psw s LEFT JOIN causal_flags f
  ON f.product_id = s.product_id AND f.store_id = s.store_id AND f.week_no = s.week_no;

SELECT COUNT(*) FROM psw2;           -- must equal the row count of psw (101,094)

/*E4. Checks behind the "unmatched = no support" assumption
(i) No record in the causal file has display = 0 AND mailer = 0 (expect 0), so the file appears to list only supported weeks.*/
SELECT COUNT(*) both_zero FROM causal_cat WHERE display = '0' AND mailer = '0';
/*(ii) Weeks with a causal record have a much higher average discount (about 32.5%) than weeks without one (about 10.2%).*/
SELECT (f.product_id IS NOT NULL) AS has_causal_record, COUNT(*) n,
       ROUND(100*AVG(s.disc/s.shelf),1) avg_discount_pct
FROM psw s LEFT JOIN causal_flags f
  ON f.product_id = s.product_id AND f.store_id = s.store_id AND f.week_no = s.week_no
GROUP BY has_causal_record;

/*E5. Lift by discount depth and support type.
Baseline = a product's weeks with no discount, no display and no mailer.
Compare rows within the same discount depth only. This table is at product-store-week level, so its lift values are NOT comparable with 05_promo_lift.
EXPORT -> 07_display_mailer_lift.csv*/
WITH f AS (
  SELECT *,
    CASE WHEN disc/shelf < 0.0001 THEN '0 No discount'
         WHEN disc/shelf < 0.3    THEN '1 Under 30%'
         ELSE '2 30%+' END AS depth,
    CASE WHEN on_display = 1 AND on_mailer = 1 THEN '3 Both'
         WHEN on_display = 1 THEN '1 Display only'
         WHEN on_mailer  = 1 THEN '2 Mailer only'
         ELSE '0 Neither' END AS support
  FROM psw2),
base AS (
  SELECT product_id, AVG(units) base_units
  FROM f WHERE depth = '0 No discount' AND support = '0 Neither'
  GROUP BY product_id HAVING COUNT(*) >= 10)
SELECT depth, support, COUNT(*) n, ROUND(SUM(units)/SUM(base_units), 2) lift_index
FROM f JOIN base USING (product_id)
GROUP BY depth, support
ORDER BY depth, support;