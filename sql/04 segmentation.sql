/*04_segmentation.sql
Business question: who buys soft drinks, and do shoppers differ in how much they buy on deep discounts?
Method: RFM scoring (recency, frequency, spend), then four named segments.
Uses the cat_tx view from 02_category_snapshot.sql.
Note: this shows who BUYS on promotion, not who was CAUSED to buy by it.*/

USE dunnhumby;

/*1. One row per household: last purchase day, number of trips, spend, and share of units bought with any discount
(any discount includes routine loyalty-card discounts, so it is high for everyone).*/
DROP TABLE IF EXISTS hh_base;
CREATE TABLE hh_base AS
SELECT household_key, MAX(day) last_day, COUNT(DISTINCT basket_id) trips,
       ROUND(SUM(sales_value),2) spend,
       ROUND(100*SUM(IF(disc>0, quantity, 0))/SUM(quantity),1) promo_unit_pct
FROM cat_tx GROUP BY household_key;

/*2. Score each household 1-4 on recency, frequency and spend (4 = best).
Ordering by last_day ascending means r = 4 is the MOST recent buyer.*/
DROP TABLE IF EXISTS hh_rfm;
CREATE TABLE hh_rfm AS
SELECT b.*,
       NTILE(4) OVER (ORDER BY last_day) r,
       NTILE(4) OVER (ORDER BY trips)    f,
       NTILE(4) OVER (ORDER BY spend)    m
FROM hh_base b;

/*3. Name the segments
(safe-updates mode is switched off for the UPDATE, then back on)*/
SET SQL_SAFE_UPDATES = 0;
ALTER TABLE hh_rfm ADD segment VARCHAR(30);
UPDATE hh_rfm SET segment = CASE
  WHEN r >= 3 AND f >= 3 THEN 'Loyal heavy buyers'
  WHEN r <= 2 AND f >= 3 THEN 'Lapsing heavy buyers'
  WHEN r >= 3 AND f <= 2 THEN 'Recent light buyers'
  ELSE 'Lapsed light buyers' END;
SET SQL_SAFE_UPDATES = 1;

/*4. Deep-discount reliance per household: share of units bought at 30%+ off.
This separates real deal-buying from routine loyalty-card discounts.*/
DROP TABLE IF EXISTS hh_deep;
CREATE TABLE hh_deep AS
SELECT household_key,
       ROUND(100*SUM(IF(disc/shelf_total >= 0.3, quantity, 0))/SUM(quantity),1) deep_promo_pct
FROM cat_tx GROUP BY household_key;

/*5. Segment profile (final result)
Check: households add up to 2,405 and total_spend to about $327,600.
EXPORT -> 08_segments.csv*/
SELECT r.segment,
       COUNT(*) households,
       ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),1) household_share_pct,
       ROUND(SUM(r.spend)) total_spend,
       ROUND(100*SUM(r.spend)/SUM(SUM(r.spend)) OVER (),1) sales_share_pct,
       ROUND(AVG(r.spend),1) avg_spend,
       ROUND(AVG(r.trips),1) avg_trips,
       ROUND(AVG(r.promo_unit_pct),1) any_discount_pct,
       ROUND(AVG(d.deep_promo_pct),1) deep_discount_pct
FROM hh_rfm r JOIN hh_deep d USING (household_key)
GROUP BY r.segment
ORDER BY total_spend DESC;