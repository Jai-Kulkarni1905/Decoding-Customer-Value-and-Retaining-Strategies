CREATE DATABASE customer_retension;
USE customer_retension;
SELECT 
    COUNT(*)
FROM
    customer_features;
DESCRIBE customer_features;
-- ======================================================================================

SELECT 
    COUNT(*) AS total_customers,
    COUNT(DISTINCT segment) AS segments,
    COUNT(DISTINCT lifetime_value_tier) AS value_tiers,
    COUNT(DISTINCT Customer_Behavior_Profile) AS behavior_profiles
FROM
    customer_features;

-- ======================================================================================
-- Q1  — Who are the genuinely loyal customers vs. those who only buy when there is a discount?
SELECT 
    segment,
    COUNT(*) AS customers,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS avg_spend,
    ROUND(AVG(`Previous Purchases`), 2) AS avg_prev_purchases,
    ROUND(AVG(`lifetime_val_score`), 2) AS avg_ltv,
    ROUND(AVG(`Brand_Commitment_Score`), 2) AS avg_commitment,
    ROUND(AVG(`Discount_Applied_Enc`), 2) AS discount_dependency,
    ROUND(AVG(`Review Rating`), 2) AS avg_rating
FROM
    customer_features
GROUP BY segment
ORDER BY avg_ltv DESC;

SELECT 
    Customer_Behavior_Profile,
    COUNT(*) AS customers,
    ROUND(AVG(`Previous Purchases`), 2) AS avg_prev_purchases,
    ROUND(AVG(`lifetime_val_score`), 2) AS avg_ltv,
    ROUND(AVG(`Discount_Applied_Enc`), 2) AS discount_dependency
FROM
    customer_features
GROUP BY Customer_Behavior_Profile
ORDER BY avg_prev_purchases DESC;

-- Premium Loyalists and Growth Customers exhibit nearly identical levels of customer value (LTV ≈ 0.62)
--  and purchase history (≈38 previous purchases). The key distinction is promotional dependency: 
--  Premium Loyalists purchase without discounts, while Growth Customers remain fully reliant on them. 
--  This suggests that a meaningful portion of the brand's highest-value customers have been conditioned
--  to buy through incentives rather than pure brand affinity.

-- ======================================================================================
-- Q2 - Behavioral Patterns predicting High Customer Value over time:

select lifetime_value_tier,
	count(*) as customers,
    round(avg(`Previous Purchases`),2) as avg_prev_purchases,
    round(avg(`freq_score`),2) as avf_frequency,
    round(avg(`Purchase Amount (USD)`),2) as avg_spend,
    round(avg(`Brand_Commitment_Score`),2) as avg_commitment,
    round(avg(`Review Rating`),2) as avg_rating,
    round(avg(`Subscription_Status_Enc`),2) as subscription_rate
FROM customer_features
group by lifetime_value_tier
order by avg(lifetime_val_score) DESC;

SELECT
    segment,
    ROUND(AVG(lifetime_val_score),2) AS avg_ltv,
    ROUND(AVG(`Previous Purchases`),2) AS avg_prev_purchases,
    ROUND(AVG(freq_score),2) AS avg_frequency,
    ROUND(AVG(`Purchase Amount (USD)`),2) AS avg_spend
FROM customer_features
GROUP BY segment
ORDER BY avg_ltv DESC;    

-- The analysis suggests that customer value is driven primarily by engagement rather than transaction 
-- size. High-value segments such as Growth Customers and Premium Loyalists exhibit nearly twice the 
-- purchase frequency and purchase history of lower-value segments, while average spend remains 
-- relatively similar across groups. This indicates that long-term customer value is created through 
-- repeated engagement and retention rather than larger individual transactions. Among the observed 
-- behaviors, purchase frequency emerges as the strongest predictor of customer value, followed by 
-- previous purchase history.
    
-- ======================================================================================
-- Q3: WHICH GEOGRAPHIES AND DEMOGRAPHICS ARE COMMERCIALLY UNDERLEVERAGED?
-- organic vs. discount-driven by state
SELECT
    Location AS state,
    COUNT(*) AS total_customers,
    ROUND(AVG(`Purchase Amount (USD)`), 2) 			AS avg_spend,
    ROUND(AVG(Discount_Applied_Enc), 2) 			AS promo_rate,
    ROUND(AVG(lifetime_val_score), 2) 				AS avg_ltv,
    ROUND(AVG(`Review Rating`), 2) 					AS avg_rating,
    -- Opportunity Score: High spend + low promo = best organic territory
    ROUND(AVG(`Purchase Amount (USD)`) * (1 - AVG(Discount_Applied_Enc)),2) AS organic_opportunity_score
FROM customer_features
GROUP BY Location
ORDER BY organic_opportunity_score DESC;

-- Top 10 underlevered states 
WITH geo_stats AS (
    SELECT
        Location,
        COUNT(*) AS customer_count,
        ROUND(AVG(`Purchase Amount (USD)`), 2) AS avg_spend,
        ROUND(AVG(Discount_Applied_Enc), 2)   AS promo_rate,
        ROUND(AVG(lifetime_val_score), 2) AS avg_ltv
    FROM customer_features
    GROUP BY Location
),
overall AS (
    SELECT 
        AVG(customer_count)  AS avg_count,
        AVG(avg_spend)       AS avg_spend_all,
        AVG(promo_rate)       AS avg_promo
    FROM geo_stats
)
SELECT
    g.Location,
    g.customer_count,
    g.avg_spend,
    g.promo_rate,
    g.avg_ltv,
    CASE
        WHEN g.avg_spend > o.avg_spend_all AND g.promo_rate < o.avg_promo AND g.customer_count < o.avg_count
            THEN 'UNDERLEVERED — High Potential'
        WHEN g.avg_spend > o.avg_spend_all AND g.promo_rate < o.avg_promo
            THEN 'Strong Organic Market'
        WHEN g.promo_rate > o.avg_promo + 10
            THEN 'Discount-Driven — Risky'
        ELSE 'Baseline'
    END                                                       AS territory_flag
FROM geo_stats g, overall o
ORDER BY g.avg_spend DESC, g.promo_rate ASC;
-- States such as Alaska, Pennsylvania, Arizona, and Illinois show higher spend with relatively 
-- low promo dependency, indicating stronger organic demand. In contrast, Iowa, Indiana, and Oregon 
-- appear more discount-driven, suggesting region-specific promotional strategies may be more effective 
-- than a uniform national approach.

-- ======================================================================================
-- Q4: How should the brand restructure the promotional structure??
SELECT
	segment,
	COUNT(*) AS customers,
	ROUND(AVG(Discount_Applied_Enc),2) AS promo_dependency,
	ROUND(AVG(`Purchase Amount (USD)`),2) AS avg_spend,
	ROUND(AVG(`Previous Purchases`),2) AS avg_previous_purchases,
	ROUND(AVG(lifetime_val_score),2) AS avg_ltv
FROM customer_features
GROUP BY segment
ORDER BY promo_dependency DESC;

SELECT
	Category,
	COUNT(*) AS customers,
	ROUND(AVG(Discount_Applied_Enc),2) AS promo_dependency,
	ROUND(AVG(`Previous Purchases`),2) AS avg_previous_purchases,
	ROUND(AVG(lifetime_val_score),2) AS avg_ltv
FROM customer_features
GROUP BY Category
ORDER BY promo_dependency DESC;

-- Revenue-at-risk if discounts removed by value tier
SELECT
    lifetime_value_tier,
    COUNT(*)                                                AS total_customers,
    SUM(CASE WHEN Discount_Applied_Enc = 1 THEN 1 ELSE 0 END)   AS promo_dependent_count,
    ROUND(SUM(CASE WHEN Discount_Applied_Enc = 1 THEN `Purchase Amount (USD)` ELSE 0 END), 2)
                                                            AS revenue_at_risk_usd,
    ROUND(SUM(`Purchase Amount (USD)`), 2)                      AS total_segment_revenue,
    ROUND(
        SUM(CASE WHEN Discount_Applied_Enc=1 THEN `Purchase Amount (USD)` ELSE 0 END) * 100.0 /
        SUM(`Purchase Amount (USD)`), 1
    )                                                       AS promo_revenue_pct
FROM customer_features
GROUP BY lifetime_value_tier
ORDER BY FIELD(lifetime_value_tier, 'Low', 'Mid', 'High', 'Premium');


-- Seasons most associated with promo usage
--      Identifies when the brand is training customers to wait for discounts
SELECT
    Season,
    COUNT(*) AS total_orders,
    SUM(Discount_Applied_Enc) AS promo_orders,
    ROUND(AVG(Discount_Applied_Enc) * 100.0, 1) AS promo_rate_pct,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS avg_spend,
    ROUND(
        AVG(CASE
                WHEN Discount_Applied_Enc = 0
                THEN `Purchase Amount (USD)`
            END), 2
    ) AS avg_spend_no_promo,

    ROUND(
        AVG(CASE
                WHEN Discount_Applied_Enc = 1
                THEN `Purchase Amount (USD)`
            END), 2
    ) AS avg_spend_with_promo

FROM customer_features
GROUP BY Season
ORDER BY promo_rate_pct DESC;

-- Promo dependency remains consistently high across all customer value tiers (40–45% of revenue),
 -- including the highest-value customers. Since promo usage is also relatively uniform across seasons 
--  and categories, a blanket reduction in discounts may be risky. A segment-based promo optimization 
--  strategy is likely to be more effective than broad promotional cuts.

-- ======================================================================================
-- Q5: What does the brands ideal customer profile look like? 
SELECT
    'IDEAL CUSTOMER PROFILE'                            AS segment_label,
    ROUND(AVG(Age), 1)                                  AS avg_age,
    -- Gender split
    ROUND(SUM(CASE WHEN Gender='Male' THEN 1 ELSE 0 END)*100.0/COUNT(*), 1) AS male_pct,
    ROUND(SUM(CASE WHEN Gender='Female' THEN 1 ELSE 0 END)*100.0/COUNT(*), 1) AS female_pct,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                  AS avg_spend,
    ROUND(AVG(`Previous Purchases`), 1)                   AS avg_prev_purchases,
    ROUND(AVG(`Review Rating`), 2)                        AS avg_rating,
    ROUND(AVG(freq_score), 1)             AS avg_annual_freq,
    ROUND(AVG(lifetime_val_score), 4)                 AS avg_value_score,
    -- Most common attributes  
    (SELECT `Payment Method` FROM customer_features 
     WHERE lifetime_value_tier='High' AND is_loyal_behavioral=1 
     GROUP BY `Payment Method` ORDER BY COUNT(*) DESC LIMIT 1) AS top_payment_method,
    (SELECT Season FROM customer_features 
     WHERE lifetime_value_tier='High' AND is_loyal_behavioral=1 
     GROUP BY Season ORDER BY COUNT(*) DESC LIMIT 1)          AS top_season,
    (SELECT Category FROM customer_features 
     WHERE lifetime_value_tier='High' AND is_loyal_behavioral=1 
     GROUP BY Category ORDER BY COUNT(*) DESC LIMIT 1)        AS top_category,
    (SELECT `Frequency of Purchases` FROM customer_features 
     WHERE lifetime_value_tier='High' AND is_loyal_behavioral=1 
     GROUP BY `Frequency of Purchases` ORDER BY COUNT(*) DESC LIMIT 1) AS top_frequency
FROM customer_features
WHERE lifetime_value_tier = 'High' AND is_loyal_behavioral = 1;


-- High Loyalty Tier location concentration
SELECT
    Location,
    COUNT(*)                                                AS premium_loyal_count,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                      AS avg_spend,
    ROUND(AVG(`Review Rating`), 2)                            AS avg_rating
FROM customer_features
WHERE lifetime_value_tier = 'High' AND is_loyal_behavioral = 1
GROUP BY Location
ORDER BY premium_loyal_count DESC;


-- Revenue distribution visualization 
SELECT
    lifetime_value_tier,
    COUNT(*)                                              AS customers,
    ROUND(SUM(`Purchase Amount (USD)`), 2)                    AS total_revenue,
    ROUND(SUM(`Purchase Amount (USD)`) * 100.0 / 
          (SELECT SUM(`Purchase Amount (USD)`) FROM customer_features), 1)
                                                          AS revenue_share_pct,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                    AS avg_revenue_per_customer,
    SUM(is_loyal_behavioral)                                         AS loyal_customers,
    SUM(`Discount_Applied_Enc`)                                  AS promo_customers
FROM customer_features
GROUP BY lifetime_value_tier
ORDER BY FIELD(lifetime_value_tier, 'High', 'Normal', 'Low', 'Risk');

-- The ideal customer is a middle-aged, high-engagement customer who spends significantly above average,
-- purchases frequently, and demonstrates strong long-term value. This segment exhibits nearly 40 previous
-- purchases on average and generates substantially higher revenue than the overall customer base.

-- =============================================================================
-- Entry vs. Retention Categories
-- Which categories appear among low-purchase customers vs. high-purchase ones?
SELECT
    Category,
    ROUND(AVG(`Previous Purchases`), 2)                     AS avg_prev_purchases,
    COUNT(*)                                               AS total,
    SUM(CASE WHEN `Previous Purchases` <= 10 THEN 1 ELSE 0 END) AS low_history_customers,
    SUM(CASE WHEN `Previous Purchases` >= 35 THEN 1 ELSE 0 END) AS high_history_customers,
    ROUND(SUM(CASE WHEN `Previous Purchases`<=10 THEN 1 ELSE 0 END)*100.0/COUNT(*), 1)
                                                           AS entry_customer_pct,
    ROUND(SUM(CASE WHEN `Previous Purchases`>=35 THEN 1 ELSE 0 END)*100.0/COUNT(*), 1)
                                                           AS retention_customer_pct
FROM customer_features
GROUP BY Category
ORDER BY avg_prev_purchases DESC;


-- ======================================================================================
--  high value customers vs low value customers?
SELECT
    lifetime_value_tier,
    COUNT(*) AS customers,
    ROUND(AVG(`Purchase Amount (USD)`),2) AS avg_spend,
    ROUND(AVG(`Previous Purchases`),2) AS avg_prev_purchases,
    ROUND(AVG(lifetime_val_score),2) AS avg_ltv,
    ROUND(AVG(Brand_Commitment_Score),2) AS avg_commitment,
    ROUND(AVG(`Review Rating`),2) AS avg_rating

FROM customer_features
GROUP BY lifetime_value_tier
ORDER BY avg_ltv DESC;

-- ======================================================================================
-- Pofiles showing strongest reapeat puchase behavior
SELECT
    Customer_Behavior_Profile,
    COUNT(*) AS customers,
    ROUND(AVG(`Previous Purchases`),2) AS avg_prev_purchases,
    ROUND(AVG(`Purchase Amount (USD)`),2) AS avg_spend,
    ROUND(AVG(Brand_Commitment_Score),2) AS avg_commitment
FROM customer_features
GROUP BY Customer_Behavior_Profile
ORDER BY avg_prev_purchases DESC;

-- ======================================================================================
-- Categories and Seasons Driving Retension
SELECT
    Category,
    Season,
    COUNT(*) AS customers,
    ROUND(AVG(`Previous Purchases`),2) AS avg_prev_purchases,
    ROUND(AVG(lifetime_val_score),2) AS avg_ltv,
    ROUND(AVG(Brand_Commitment_Score),2) AS avg_commitment
FROM customer_features
GROUP BY
    Category,
    Season
ORDER BY avg_prev_purchases DESC;

-- ======================================================================================
-- Organic vs Discount Driven Demand

WITH geo_metrics AS
(
SELECT
    Location,
    ROUND(AVG(`Purchase Amount (USD)`),2) AS avg_spend,
    ROUND(AVG(Discount_Applied_Enc),2) AS discount_rate,
    COUNT(*) AS customers
FROM customer_features
GROUP BY Location
)
SELECT
    Location,
    customers,
    avg_spend,
    discount_rate,
    CASE
        WHEN avg_spend >= 60
             AND discount_rate < 0.50
        THEN 'Organic Demand'
        WHEN avg_spend >= 60
             AND discount_rate >= 0.50
        THEN 'Discount Driven Volume'
        WHEN avg_spend < 60
             AND discount_rate < 0.50
        THEN 'Low Spend Organic'
        ELSE 'Low Spend Promo Driven'
    END AS market_type
FROM geo_metrics
ORDER BY avg_spend DESC;