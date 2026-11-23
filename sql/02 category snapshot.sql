/*02_category_snapshot.sql
Business question: what does the soft drinks category look like?
Steps:
1. Screen categories and choose one
2. Build the clean working view (cat_tx)
3. Category snapshot: KPIs, brand share, weekly trend, top manufacturers
Queries marked EXPORT are saved as CSV from the result grid for Power BI.*/

USE dunnhumby;
/*1. Category screening
Goal: pick a branded packaged-food/drink category with enough buyers, real competition (many manufacturers), some private label, and real promotions.
Result: SOFT DRINKS (about 96% of households buy it, 37 manufacturers, 11.3% private label, 67.8% of sales carry a discount).
EXPORT -> 00_screening.csv (optional, for an appendix slide)*/
SELECT p.commodity_desc,
       ROUND(SUM(t.sales_value)) sales,
       COUNT(DISTINCT t.household_key) buyers,
       COUNT(DISTINCT p.manufacturer) manufacturers,
       ROUND(100*SUM(IF(p.brand='Private', t.sales_value, 0))/SUM(t.sales_value),1) private_label_pct,
       ROUND(100*SUM(IF(-(t.retail_disc+t.coupon_match_disc) > 0, t.sales_value, 0))/SUM(t.sales_value),1) promo_sales_pct
FROM transactions t JOIN product p USING (product_id)
WHERE t.quantity > 0 AND p.department = 'GROCERY'
GROUP BY p.commodity_desc
ORDER BY sales DESC
LIMIT 25;

/*2. Working view: soft drinks purchases only
disc = total discount on the purchase (retailer discount + coupon match; stored as negative numbers in the raw data, so the sign is flipped)
shelf_total = price before discounts (what was paid + the discount)
Rows with zero/negative quantity or non-positive shelf price are dropped.*/
DROP VIEW IF EXISTS cat_tx;
CREATE VIEW cat_tx AS
SELECT t.*, p.brand, p.manufacturer,
       -(t.retail_disc + t.coupon_match_disc) AS disc,
       t.sales_value - (t.retail_disc + t.coupon_match_disc) AS shelf_total
FROM transactions t JOIN product p USING (product_id)
WHERE p.commodity_desc = 'SOFT DRINKS' AND t.quantity > 0
  AND t.sales_value - (t.retail_disc + t.coupon_match_disc) > 0;

/*3a. KPIs
EXPORT -> 01_kpis.csv*/
SELECT COUNT(DISTINCT household_key) buyers,
       ROUND(COUNT(DISTINCT household_key)/(SELECT COUNT(DISTINCT household_key) FROM transactions),2) penetration,
       ROUND(SUM(sales_value)) sales, SUM(quantity) units,
       ROUND(SUM(sales_value)/COUNT(DISTINCT household_key),1) spend_per_buyer
FROM cat_tx;

/*3b. Brand share: national brands vs private label
EXPORT -> 02_brand_share.csv*/
SELECT brand, ROUND(SUM(sales_value)) sales,
       ROUND(100*SUM(sales_value)/SUM(SUM(sales_value)) OVER (),1) share_pct
FROM cat_tx GROUP BY brand;

/*3c. Weekly trend: sales, units, active buyers and share of sales sold on discount.
Note: the first ~14 weeks have far fewer active buyers, so trend charts use week 15 onwards.
EXPORT -> 03_weekly_trend.csv*/
SELECT week_no,
       ROUND(SUM(sales_value)) sales,
       SUM(quantity) units,
       COUNT(DISTINCT household_key) buyers,
       ROUND(100*SUM(IF(disc > 0, sales_value, 0))/SUM(sales_value),1) promo_sales_pct
FROM cat_tx
GROUP BY week_no
ORDER BY week_no;

/*3d. Top 10 manufacturers: market concentration and promotion reliance.
(Manufacturer 69 is the private label: its sales equal the private-label total.)
EXPORT -> 04_manufacturers.csv*/
SELECT manufacturer,
       ROUND(SUM(sales_value)) sales,
       ROUND(100*SUM(sales_value)/SUM(SUM(sales_value)) OVER (),1) share_pct,
       COUNT(DISTINCT product_id) products,
       ROUND(100*SUM(IF(disc > 0, sales_value, 0))/SUM(sales_value),1) promo_sales_pct
FROM cat_tx
GROUP BY manufacturer
ORDER BY sales DESC
LIMIT 10;
