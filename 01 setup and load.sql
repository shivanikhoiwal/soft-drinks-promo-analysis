/*01_setup_and_load.sql
Promotion Effectiveness & Shopper Segmentation: Soft Drinks (FMCG/CPG)
Data : Dunnhumby "The Complete Journey" (raw files are NOT included in this repo)
Tool : MySQL 8.0+
Run the files in order: 01 -> 02 -> 03 -> 04
Run THIS file only once: it creates the base tables and loads the CSVs*/

CREATE DATABASE IF NOT EXISTS dunnhumby;
USE dunnhumby;

/*Base tables (column order must match the CSV headers)*/

/*One row per product line bought in a basket*/
CREATE TABLE transactions (
  household_key INT, basket_id BIGINT, day INT, product_id INT, quantity INT,
  sales_value DECIMAL(10,2), store_id INT, retail_disc DECIMAL(10,2), trans_time INT,
  week_no INT, coupon_disc DECIMAL(10,2), coupon_match_disc DECIMAL(10,2));

/*Product lookup (manufacturer, brand = National/Private, commodity)*/
CREATE TABLE product (
  product_id INT, manufacturer INT, department VARCHAR(50), brand VARCHAR(20),
  commodity_desc VARCHAR(80), sub_commodity_desc VARCHAR(80), curr_size_of_product VARCHAR(30));

/*Household information. Loaded for completeness but NOT used in the analysis:
in this version of the data the demographic columns are anonymised (classification_1 ... classification_5), so they cannot be interpreted.*/
CREATE TABLE hh_demographic (
  classification_1 VARCHAR(20), classification_2 VARCHAR(5), classification_3 VARCHAR(10),
  homeowner_desc VARCHAR(30), classification_5 VARCHAR(10), classification_4 VARCHAR(5),
  kid_category_desc VARCHAR(20), household_key INT);

/*Display / mailer support by product, store and week*/
CREATE TABLE causal_data (product_id INT, store_id INT, week_no INT, display VARCHAR(5), mailer VARCHAR(5));

/*Load the CSVs*/
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/path/to/data/transaction_data.csv' INTO TABLE transactions
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/path/to/data/product.csv' INTO TABLE product
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'C:/path/to/data/hh_demographic.csv' INTO TABLE hh_demographic
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES;

/*Load causal_data ONCE. If your CSV has Windows line endings and rows fail to load, try '\r\n' instead of '\n'.
Any stray carriage returns in the last column are stripped later (see the causal_cat step in 03_promo_analysis.sql).*/
LOAD DATA LOCAL INFILE 'C:/path/to/data/causal_data.csv' INTO TABLE causal_data
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES
(product_id, store_id, week_no, display, mailer);

/*Indexes*/
CREATE INDEX i1 ON transactions(product_id);
CREATE INDEX i2 ON transactions(household_key);
CREATE INDEX i3 ON transactions(week_no);
CREATE INDEX i4 ON causal_data(product_id);

/*Sanity check: expect about 2.6 million rows*/
SELECT COUNT(*) AS transaction_rows FROM transactions;