# soft-drinks-promo-analysis
# Promotion Effectiveness & Shopper Segmentation: Soft Drinks (FMCG/CPG)

Independent analytics project.

## Business question
Do promotions pay off in the soft drinks category, and which shoppers buy on promotion?

## Data
Dunnhumby "The Complete Journey" (about 2,500 households, 102 weeks of retail transactions).
Raw data is not included. Download it from dunnhumby: https://www.dunnhumby.com/source-files/.

## Tools
MySQL 8, Power BI

## Approach
1. Screened categories on sales, buyers, manufacturers, private label share and promo share; chose Soft Drinks
2. Built a clean category view with shelf price and discount per purchase
3. Measured promotion lift against each product's own no-discount weeks, with robustness checks
4. Estimated promo payback: incremental units and discount cost per extra unit
5. Tested the added effect of display and mailer support
6. Segmented households with RFM scoring and compared deep-discount buying

## Key findings
- Two manufacturers hold about 66% of category sales; private label is about 11%
- Discounts under 20% lift volume only about 1.3x; 30-40% about 3x; 40%+ about 5x or more
- At 10-20% discounts, about 73% of promo-week units would have sold anyway (about $1.59 of discount per extra unit); at 30%+, about 76% are extra, at about $2.32 per extra unit
- Display and mailer support added little without a discount; at 30%+, support raised lift from about 1.3x to 1.9x
- Loyal heavy buyers are about 37% of households and about 72% of sales; all segments buy about a third of units at 30%+ discount

## Limitations
- Public retail data with no margins, so results show cost per extra unit, not profit
- Lift shows association, not causation (deep discounts usually come with display and mailer support)
- Weeks with no record in the display/mailer file are assumed to have no support
- Early weeks have fewer active households; checked by re-running from week 15

## How to reproduce
Run the files in `sql/` in order (MySQL 8+).
