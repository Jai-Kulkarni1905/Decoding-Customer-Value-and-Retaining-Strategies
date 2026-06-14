-- =====================================================================================================================================
-- FILE       : customer_retention_analysis.sql
-- DATABASE   : customer_retention
-- TABLE      : customer_features
-- AUTHOR     : Analytics Engineering Layer
-- PURPOSE    : Business Intelligence SQL for Customer Retention & Value Analysis
-- DATASET    : 3,900 customer records | 36 columns | Post-Python feature engineering
-- =====================================================================================================================================
--
-- ╔══════════════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║                                   SCHEMA REVIEW                                                     ║
-- ╠══════════════════════════════════════════════════════════════════════════════════════════════════════╣
-- ║                                                                                                      ║
-- ║  RAW INPUT FEATURES (sourced from original dataset)                                                  ║
-- ║  ─────────────────────────────────────────────────                                                   ║
-- ║  Customer ID          INT       Primary identifier per customer record                               ║
-- ║  Age                  INT       Customer age in years (range: 18–70)                                 ║
-- ║  Gender               VARCHAR   Male / Female                                                        ║
-- ║  Item Purchased       VARCHAR   Specific product bought in this transaction                          ║
-- ║  Category             VARCHAR   Product category: Clothing, Accessories, Footwear, Outerwear        ║
-- ║  Purchase Amount(USD) INT       Transaction value in USD (range: $20–$100)                           ║
-- ║  Location             VARCHAR   US state of the customer (all 50 states represented)                 ║
-- ║  Size                 VARCHAR   Product size: S / M / L / XL                                         ║
-- ║  Color                VARCHAR   Product color selected                                               ║
-- ║  Season               VARCHAR   Season of purchase: Fall, Spring, Summer, Winter                     ║
-- ║  Review Rating        DECIMAL   Customer review score (scale 1.0–5.0)                                ║
-- ║  Subscription Status  VARCHAR   Whether customer holds a brand subscription: Yes / No               ║
-- ║  Shipping Type        VARCHAR   Delivery method: Express, Standard, Next Day, etc.                   ║
-- ║  Discount Applied     VARCHAR   Whether a discount was applied: Yes / No                             ║
-- ║  Promo Code Used      VARCHAR   Whether a promo code was used: Yes / No                              ║
-- ║  Previous Purchases   INT       Number of prior purchases (proxy for customer tenure; range 1–50)    ║
-- ║  Payment Method       VARCHAR   Payment channel: Credit Card, PayPal, Venmo, etc.                   ║
-- ║  Frequency ofPurchase VARCHAR   Purchase cadence: Annually, Quarterly, Monthly, Fortnightly, Weekly ║
-- ║                                                                                                      ║
-- ║  ENGINEERED FEATURES (computed in Python feature engineering phase)                                  ║
-- ║  ──────────────────────────────────────────────────────────────────                                  ║
-- ║  Discount_Applied_Enc INT       Binary encoding of Discount Applied (1=Yes, 0=No)                   ║
-- ║  Promo_Code_Used_Enc  INT       Binary encoding of Promo Code Used (1=Yes, 0=No)                    ║
-- ║  Subscription_Status_Enc INT    Binary encoding of Subscription Status (1=Yes, 0=No)                ║
-- ║                                                                                                      ║
-- ║  freq_score           INT       Numeric purchase frequency: 1=Annual, 4=Quarterly, 12=Monthly,      ║
-- ║                                 26=Fortnightly, 52=Weekly — higher score = more frequent buyer       ║
-- ║                                                                                                      ║
-- ║  age_band             VARCHAR   Bucketed age groups: 18-29, 30-39, 40-49, 50-59, 60-70              ║
-- ║                                                                                                      ║
-- ║  prev_norm            DECIMAL   Min-max normalised Previous Purchases (0–1 scale)                   ║
-- ║                                 Higher value = longer tenure, more purchase history                  ║
-- ║                                                                                                      ║
-- ║  spend_norm           DECIMAL   Min-max normalised Purchase Amount (0–1 scale)                      ║
-- ║                                 Higher value = higher single-transaction spend                        ║
-- ║                                                                                                      ║
-- ║  rating_norm          DECIMAL   Min-max normalised Review Rating (0–1 scale)                        ║
-- ║                                 Higher value = higher satisfaction with purchase                     ║
-- ║                                                                                                      ║
-- ║  freq_norm            DECIMAL   Min-max normalised freq_score (0–1 scale)                           ║
-- ║                                 Higher value = more frequent purchaser                               ║
-- ║                                                                                                      ║
-- ║  lifetime_val_score   DECIMAL   Composite LTV proxy (0–1 scale); weighted blend of                  ║
-- ║                                 spend_norm, prev_norm, freq_norm, rating_norm, subscription          ║
-- ║                                 Higher = greater predicted lifetime economic contribution             ║
-- ║                                                                                                      ║
-- ║  lifetime_value_tier  VARCHAR   LTV segment bucket: High, Normal, Low, Risk                         ║
-- ║                                 Risk = high promo dependency + low organic value indicators          ║
-- ║                                                                                                      ║
-- ║  Satisfaction_Flag    INT       Binary: 1 = Satisfied, 0 = Not Satisfied                            ║
-- ║  Satisfaction_Label   VARCHAR   Human-readable satisfaction: Satisfied, Neutral, Dissatisfied        ║
-- ║                                                                                                      ║
-- ║  Customer_Behavior_Profile VARCHAR  Behavioural archetype assigned by Python model:                  ║
-- ║                                 - Loyal NonSubscribers: Buy organically, no sub required            ║
-- ║                                 - Discount Subscriber: Hold subscription but need discounts          ║
-- ║                                 - Discount NonSubscribers: No sub and discount-dependent             ║
-- ║                                                                                                      ║
-- ║  Urgency_Score        INT       Purchase urgency signal (-1 to 4); higher = more urgent/impulsive   ║
-- ║                                 buyer. Derived from shipping type and discount combination           ║
-- ║                                                                                                      ║
-- ║  is_loyal_behavioral  INT       Binary loyalty flag (1=Loyal, 0=Not Loyal)                         ║
-- ║                                 Derived from organic purchase behavior, not just repurchase count    ║
-- ║                                                                                                      ║
-- ║  segment              VARCHAR   Strategic customer segment assigned by Python model:                 ║
-- ║                                 - Premium Loyalists  : High value + high loyalty                    ║
-- ║                                 - Organic High-Value : High value, loyalty varies                   ║
-- ║                                 - Growth Customers   : Loyal but moderate value                     ║
-- ║                                 - Promo-Driven Buyers: Value conditioned on promotions              ║
-- ║                                                                                                      ║
-- ║  Brand_Commitment_Score DECIMAL  Composite brand affinity score (-0.08 to 0.70)                     ║
-- ║                                 Derived from subscription, loyalty, frequency, and satisfaction      ║
-- ║                                 Higher = stronger brand relationship, more retention-resistant        ║
-- ║                                                                                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════════
-- DATABASE CONTEXT
-- ═══════════════════════════════════════════════════════════════════════
USE customer_retention;


-- =====================================================
-- QUERY 1A
-- BUSINESS QUESTION: WHO ARE THE ORGANICALLY LOYAL
-- CUSTOMERS vs. PROMO-CONDITIONED CUSTOMERS?
-- Segment Comparison: Loyalty vs Promo Dependency
-- =====================================================
-- WHAT IT MEASURES:
--   Compares loyalty segments side by side across spend, promo dependency,
--   repeat purchases, satisfaction, and brand commitment.
-- HOW TO INTERPRET:
--   Organic Loyalists = is_loyal_behavioral=1 with zero promo usage.
--   Promo-Conditioned = is_loyal_behavioral=0 with both discount + promo usage.
--   Rows with high Brand_Commitment_Score and zero promo dependency are
--   the brand's healthiest cohort.
-- DASHBOARD RELEVANCE:
--   Core KPI card — Customer Health by Loyalty Type.

WITH loyalty_classification AS (
    SELECT
        -- ── Loyalty Label ─────────────────────────────────────────────
        CASE
            WHEN is_loyal_behavioral = 1
             AND Discount_Applied_Enc = 0
             AND Promo_Code_Used_Enc  = 0 THEN 'Organically Loyal'
            WHEN is_loyal_behavioral = 1
             AND (Discount_Applied_Enc = 1 OR Promo_Code_Used_Enc = 1) THEN 'Loyal but Promo-Assisted'
            WHEN is_loyal_behavioral = 0
             AND Discount_Applied_Enc = 1
             AND Promo_Code_Used_Enc  = 1 THEN 'Promo-Conditioned'
            ELSE 'Occasional / At-Risk'
        END                                             AS loyalty_type,

        -- ── Core Metrics ──────────────────────────────────────────────
        `Purchase Amount (USD)`                         AS spend,
        `Previous Purchases`                            AS repeat_purchases,
        `Review Rating`                                 AS satisfaction_score,
        Brand_Commitment_Score,
        lifetime_val_score,
        Discount_Applied_Enc                            AS used_discount,
        Promo_Code_Used_Enc                             AS used_promo,
        freq_score,
        Subscription_Status_Enc                         AS is_subscriber,
        segment,
        Customer_Behavior_Profile
    FROM customer_features
)

SELECT
    loyalty_type,
    COUNT(*)                                            AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total,

    -- ── Spend Profile ─────────────────────────────────────────────────
    ROUND(AVG(spend), 2)                                AS avg_spend_usd,
    ROUND(MIN(spend), 2)                                AS min_spend_usd,
    ROUND(MAX(spend), 2)                                AS max_spend_usd,

    -- ── Repeat Purchase Behaviour ─────────────────────────────────────
    ROUND(AVG(repeat_purchases), 2)                     AS avg_repeat_purchases,

    -- ── Satisfaction ──────────────────────────────────────────────────
    ROUND(AVG(satisfaction_score), 2)                   AS avg_review_rating,

    -- ── Promo Dependency ──────────────────────────────────────────────
    ROUND(AVG(used_discount) * 100, 1)                  AS pct_discount_used,
    ROUND(AVG(used_promo)    * 100, 1)                  AS pct_promo_code_used,

    -- ── Brand Health ──────────────────────────────────────────────────
    ROUND(AVG(Brand_Commitment_Score), 3)               AS avg_brand_commitment,
    ROUND(AVG(lifetime_val_score),     3)               AS avg_ltv_score,

    -- ── Purchase Frequency ────────────────────────────────────────────
    ROUND(AVG(freq_score), 1)                           AS avg_freq_score,
    ROUND(AVG(is_subscriber) * 100, 1)                  AS pct_subscribers

FROM loyalty_classification
GROUP BY loyalty_type
ORDER BY avg_ltv_score DESC;


-- =====================================================
-- QUERY 1B
-- BUSINESS QUESTION: LOYALTY SEGMENT PROFILE
-- Deep-Dive Comparison by Engineered Segment
-- =====================================================
-- WHAT IT MEASURES:
--   Breaks down the four Python-assigned segments by promo dependency,
--   satisfaction, and LTV — confirming whether segment labels align
--   with observed spending and loyalty behaviour.
-- HOW TO INTERPRET:
--   Premium Loyalists should show lowest promo use + highest brand score.
--   Promo-Driven Buyers should show inverse pattern.
-- DASHBOARD RELEVANCE:
--   Segment Breakdown panel — loyalty vs promo dependency matrix.

SELECT
    segment,
    Customer_Behavior_Profile                            AS behavior_archetype,
    COUNT(*)                                             AS customer_count,

    -- Loyalty Signal
    ROUND(AVG(is_loyal_behavioral) * 100, 1)            AS pct_behaviorally_loyal,
    ROUND(AVG(Brand_Commitment_Score), 3)                AS avg_brand_commitment,

    -- Promo Dependency
    ROUND(AVG(Discount_Applied_Enc) * 100, 1)           AS pct_used_discount,
    ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)           AS pct_used_promo,

    -- Spend
    ROUND(AVG(`Purchase Amount (USD)`), 2)               AS avg_spend_usd,

    -- Repeat Purchases
    ROUND(AVG(`Previous Purchases`), 2)                  AS avg_prev_purchases,

    -- Satisfaction
    ROUND(AVG(`Review Rating`), 2)                       AS avg_rating,
    ROUND(AVG(Satisfaction_Flag) * 100, 1)               AS pct_satisfied,

    -- LTV
    ROUND(AVG(lifetime_val_score), 3)                    AS avg_ltv_score

FROM customer_features
GROUP BY segment, Customer_Behavior_Profile
ORDER BY avg_ltv_score DESC, avg_brand_commitment DESC;


-- =====================================================
-- QUERY 2
-- BUSINESS QUESTION: WHICH BEHAVIORAL PATTERNS TODAY
-- PREDICT HIGH CUSTOMER VALUE OVER TIME?
-- High vs Medium vs Low LTV Tier Comparison
-- =====================================================
-- WHAT IT MEASURES:
--   Profiles each LTV tier (High, Normal, Low, Risk) across all key
--   behavioral indicators to surface which factors most strongly
--   differentiate high-value from low-value customers.
-- HOW TO INTERPRET:
--   Columns with the greatest spread between the High and Risk tiers
--   are the strongest LTV predictors. Focus particularly on
--   prev_norm, freq_norm, Brand_Commitment_Score, and subscription.
-- DASHBOARD RELEVANCE:
--   LTV Predictor Scorecard — helps marketing prioritise acquisition
--   signals and retention triggers.

WITH ltv_profiles AS (
    SELECT
        lifetime_value_tier                               AS ltv_tier,

        -- Purchase History (Tenure Proxy)
        `Previous Purchases`                              AS prev_purchases,
        prev_norm                                         AS prev_norm_score,

        -- Spend
        `Purchase Amount (USD)`                           AS spend,
        spend_norm                                        AS spend_norm_score,

        -- Frequency
        `Frequency of Purchases`                          AS freq_label,
        freq_score                                        AS freq_value,
        freq_norm                                         AS freq_norm_score,

        -- Loyalty
        is_loyal_behavioral                               AS is_loyal,
        Brand_Commitment_Score,

        -- Subscription
        Subscription_Status_Enc                           AS is_subscriber,

        -- Satisfaction
        `Review Rating`                                   AS rating,
        rating_norm                                       AS rating_norm_score,
        Satisfaction_Flag,

        -- Promo Dependency
        Discount_Applied_Enc                              AS used_discount,
        Promo_Code_Used_Enc                               AS used_promo,

        -- Composite LTV
        lifetime_val_score,

        -- Urgency
        Urgency_Score

    FROM customer_features
)

SELECT
    ltv_tier,
    COUNT(*)                                              AS customer_count,

    -- ── Purchase History ──────────────────────────────────────────────
    ROUND(AVG(prev_purchases), 2)                         AS avg_prev_purchases,
    ROUND(AVG(prev_norm_score), 4)                        AS avg_prev_norm,

    -- ── Spend ─────────────────────────────────────────────────────────
    ROUND(AVG(spend), 2)                                  AS avg_spend_usd,
    ROUND(AVG(spend_norm_score), 4)                       AS avg_spend_norm,

    -- ── Frequency ─────────────────────────────────────────────────────
    ROUND(AVG(freq_value), 2)                             AS avg_freq_score,
    ROUND(AVG(freq_norm_score), 4)                        AS avg_freq_norm,

    -- ── Loyalty ───────────────────────────────────────────────────────
    ROUND(AVG(is_loyal) * 100, 1)                         AS pct_behaviorally_loyal,
    ROUND(AVG(Brand_Commitment_Score), 4)                 AS avg_brand_commitment,

    -- ── Subscription ──────────────────────────────────────────────────
    ROUND(AVG(is_subscriber) * 100, 1)                    AS pct_subscribers,

    -- ── Satisfaction ──────────────────────────────────────────────────
    ROUND(AVG(rating), 2)                                 AS avg_rating,
    ROUND(AVG(Satisfaction_Flag) * 100, 1)                AS pct_satisfied,

    -- ── Promo Dependency ──────────────────────────────────────────────
    ROUND(AVG(used_discount) * 100, 1)                    AS pct_used_discount,
    ROUND(AVG(used_promo)    * 100, 1)                    AS pct_used_promo,

    -- ── Composite LTV ─────────────────────────────────────────────────
    ROUND(AVG(lifetime_val_score), 4)                     AS avg_composite_ltv,
    ROUND(MIN(lifetime_val_score), 4)                     AS min_ltv,
    ROUND(MAX(lifetime_val_score), 4)                     AS max_ltv,

    -- ── Urgency ───────────────────────────────────────────────────────
    ROUND(AVG(Urgency_Score), 2)                          AS avg_urgency_score

FROM ltv_profiles
GROUP BY ltv_tier
ORDER BY
    FIELD(ltv_tier, 'High', 'Normal', 'Low', 'Risk');


-- =====================================================
-- QUERY 2B
-- STRONGEST LTV PREDICTORS — RANKED DIFFERENTIATORS
-- Spread Analysis: High vs Risk Tier
-- =====================================================
-- WHAT IT MEASURES:
--   Calculates the absolute spread on each normalised metric between
--   High and Risk LTV tiers. Metrics with the largest spread are the
--   strongest predictors of customer value.
-- HOW TO INTERPRET:
--   Output ranked by spread descending.
--   Top rows = most powerful predictors for targeting and scoring.
-- DASHBOARD RELEVANCE:
--   Feature Importance table for internal analytics / data science handoff.

WITH tier_avgs AS (
    SELECT
        lifetime_value_tier                               AS ltv_tier,
        AVG(prev_norm)                                    AS avg_prev_norm,
        AVG(spend_norm)                                   AS avg_spend_norm,
        AVG(freq_norm)                                    AS avg_freq_norm,
        AVG(rating_norm)                                  AS avg_rating_norm,
        AVG(Brand_Commitment_Score)                       AS avg_brand_commit,
        AVG(Subscription_Status_Enc)                      AS avg_subscription,
        AVG(Discount_Applied_Enc)                         AS avg_discount,
        AVG(Promo_Code_Used_Enc)                          AS avg_promo
    FROM customer_features
    GROUP BY lifetime_value_tier
),

high_tier AS (
    SELECT * FROM tier_avgs WHERE ltv_tier = 'High'
),

risk_tier AS (
    SELECT * FROM tier_avgs WHERE ltv_tier = 'Risk'
)

SELECT
    'Previous Purchases (Tenure)'          AS predictor,
    ROUND(h.avg_prev_norm, 4)              AS high_tier_avg,
    ROUND(r.avg_prev_norm, 4)              AS risk_tier_avg,
    ROUND(ABS(h.avg_prev_norm - r.avg_prev_norm), 4)  AS spread
FROM high_tier h, risk_tier r

UNION ALL SELECT 'Purchase Frequency',
    ROUND(h.avg_freq_norm, 4),
    ROUND(r.avg_freq_norm, 4),
    ROUND(ABS(h.avg_freq_norm - r.avg_freq_norm), 4)
FROM high_tier h, risk_tier r

UNION ALL SELECT 'Brand Commitment Score',
    ROUND(h.avg_brand_commit, 4),
    ROUND(r.avg_brand_commit, 4),
    ROUND(ABS(h.avg_brand_commit - r.avg_brand_commit), 4)
FROM high_tier h, risk_tier r

UNION ALL SELECT 'Subscription Status',
    ROUND(h.avg_subscription, 4),
    ROUND(r.avg_subscription, 4),
    ROUND(ABS(h.avg_subscription - r.avg_subscription), 4)
FROM high_tier h, risk_tier r

UNION ALL SELECT 'Review Rating (Satisfaction)',
    ROUND(h.avg_rating_norm, 4),
    ROUND(r.avg_rating_norm, 4),
    ROUND(ABS(h.avg_rating_norm - r.avg_rating_norm), 4)
FROM high_tier h, risk_tier r

UNION ALL SELECT 'Spend per Transaction',
    ROUND(h.avg_spend_norm, 4),
    ROUND(r.avg_spend_norm, 4),
    ROUND(ABS(h.avg_spend_norm - r.avg_spend_norm), 4)
FROM high_tier h, risk_tier r

UNION ALL SELECT 'Promo Code Usage (Inverse)',
    ROUND(h.avg_promo, 4),
    ROUND(r.avg_promo, 4),
    ROUND(ABS(h.avg_promo - r.avg_promo), 4)
FROM high_tier h, risk_tier r

UNION ALL SELECT 'Discount Dependency (Inverse)',
    ROUND(h.avg_discount, 4),
    ROUND(r.avg_discount, 4),
    ROUND(ABS(h.avg_discount - r.avg_discount), 4)
FROM high_tier h, risk_tier r

ORDER BY spread DESC;


-- =====================================================
-- QUERY 3A
-- BUSINESS QUESTION: WHICH GEOGRAPHIES ARE COMMERCIALLY
-- UNDERLEVERAGED?
-- Geography Performance Matrix
-- =====================================================
-- WHAT IT MEASURES:
--   Ranks all US states by average spend, LTV, promo dependency,
--   loyalty rate, and brand commitment. Identifies states with high
--   spend + low promo use = strongest organic demand.
-- HOW TO INTERPRET:
--   States in the top quartile for avg_spend_usd AND low pct_promo_used
--   are organic demand hotspots. States with high spend but high promo
--   use are commercially active but margin-risky.
-- DASHBOARD RELEVANCE:
--   Geographic performance heatmap / state-level BI dashboard.

WITH geo_metrics AS (
    SELECT
        Location                                          AS state,
        COUNT(*)                                          AS customer_count,

        -- Spend
        ROUND(AVG(`Purchase Amount (USD)`), 2)            AS avg_spend_usd,
        ROUND(SUM(`Purchase Amount (USD)`), 0)            AS total_revenue_usd,

        -- Loyalty
        ROUND(AVG(is_loyal_behavioral) * 100, 1)          AS pct_loyal,
        ROUND(AVG(Brand_Commitment_Score), 3)              AS avg_brand_commitment,

        -- Promo Dependency
        ROUND(AVG(Discount_Applied_Enc) * 100, 1)         AS pct_discount_used,
        ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)         AS pct_promo_used,

        -- LTV
        ROUND(AVG(lifetime_val_score), 3)                 AS avg_ltv_score,

        -- Satisfaction
        ROUND(AVG(`Review Rating`), 2)                    AS avg_rating

    FROM customer_features
    GROUP BY Location
),

-- Compute global medians for quartile classification
global_stats AS (
    SELECT
        AVG(avg_spend_usd)   AS global_avg_spend,
        AVG(pct_promo_used)  AS global_avg_promo
    FROM geo_metrics
)

SELECT
    gm.state,
    gm.customer_count,
    gm.avg_spend_usd,
    gm.total_revenue_usd,
    gm.pct_loyal,
    gm.avg_brand_commitment,
    gm.pct_discount_used,
    gm.pct_promo_used,
    gm.avg_ltv_score,
    gm.avg_rating,

    -- ── Commercial Opportunity Classification ─────────────────────────
    CASE
        WHEN gm.avg_spend_usd >= gs.global_avg_spend
         AND gm.pct_promo_used < gs.global_avg_promo  THEN 'Organic Demand — Premium Opportunity'
        WHEN gm.avg_spend_usd >= gs.global_avg_spend
         AND gm.pct_promo_used >= gs.global_avg_promo THEN 'Discount-Driven Volume — Margin Risk'
        WHEN gm.avg_spend_usd < gs.global_avg_spend
         AND gm.pct_promo_used < gs.global_avg_promo  THEN 'Underleveraged — Acquisition Opportunity'
        ELSE                                              'Promo-Dependent Low Spend — Deprioritise'
    END                                                   AS geo_classification

FROM geo_metrics gm
CROSS JOIN global_stats gs
ORDER BY gm.avg_ltv_score DESC, gm.avg_spend_usd DESC;


-- =====================================================
-- QUERY 3B
-- BUSINESS QUESTION: WHICH DEMOGRAPHICS ARE
-- COMMERCIALLY UNDERLEVERAGED?
-- Age Band x Gender Performance Comparison
-- =====================================================
-- WHAT IT MEASURES:
--   Breaks revenue, loyalty, promo dependency, and LTV by age band
--   and gender to surface demographic gaps.
-- HOW TO INTERPRET:
--   High avg_spend + low pct_promo_used within a demographic =
--   untapped premium segment. Consider targeted brand campaigns.
-- DASHBOARD RELEVANCE:
--   Demographic segmentation panel for campaign planning.

SELECT
    age_band,
    Gender,
    COUNT(*)                                              AS customer_count,

    -- Spend
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd,
    ROUND(SUM(`Purchase Amount (USD)`), 0)                AS total_revenue_usd,

    -- Loyalty
    ROUND(AVG(is_loyal_behavioral) * 100, 1)              AS pct_loyal,
    ROUND(AVG(Brand_Commitment_Score), 3)                 AS avg_brand_commitment,
    ROUND(AVG(Subscription_Status_Enc) * 100, 1)          AS pct_subscribers,

    -- Promo Dependency
    ROUND(AVG(Discount_Applied_Enc) * 100, 1)             AS pct_discount_used,
    ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)             AS pct_promo_used,

    -- LTV
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,

    -- Satisfaction
    ROUND(AVG(`Review Rating`), 2)                        AS avg_rating,

    -- Repeat Purchases
    ROUND(AVG(`Previous Purchases`), 2)                   AS avg_prev_purchases

FROM customer_features
GROUP BY age_band, Gender
ORDER BY avg_ltv_score DESC, avg_spend_usd DESC;


-- =====================================================
-- QUERY 4A
-- BUSINESS QUESTION: HOW SHOULD THE BRAND RESTRUCTURE
-- ITS PROMOTIONAL STRATEGY WITHOUT LOSING VOLUME?
-- Promo Dependency by Segment — Strategic Triage
-- =====================================================
-- WHAT IT MEASURES:
--   Classifies each segment by its promo dependency level and
--   estimates the volume risk and margin opportunity of reducing promos.
-- HOW TO INTERPRET:
--   - "Safe to Sunset Promos"  : High loyalty + low promo use → remove promos with no volume risk
--   - "Gradual Phase-Down"     : Moderate loyalty, moderate promo use → reduce step-by-step
--   - "Handle with Care"       : Highly promo-dependent, some loyalty → risk losing volume
--   - "Promotional Dependency" : Low loyalty + high promo use → may churn if promos removed
-- DASHBOARD RELEVANCE:
--   Promotional strategy decision matrix for CMO / commercial team.

WITH promo_segments AS (
    SELECT
        segment,
        Customer_Behavior_Profile                         AS behavior_profile,
        `Purchase Amount (USD)`                           AS spend,
        `Previous Purchases`                              AS repeat_purchases,
        Discount_Applied_Enc                              AS used_discount,
        Promo_Code_Used_Enc                               AS used_promo,
        is_loyal_behavioral                               AS is_loyal,
        Brand_Commitment_Score,
        lifetime_val_score,
        lifetime_value_tier
    FROM customer_features
)

SELECT
    segment,
    behavior_profile,
    COUNT(*)                                              AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1)    AS pct_of_total_base,

    -- Promo Dependency
    ROUND(AVG(used_discount) * 100, 1)                   AS pct_discount_used,
    ROUND(AVG(used_promo)    * 100, 1)                   AS pct_promo_used,

    -- Loyalty Shield (ability to retain without promos)
    ROUND(AVG(is_loyal) * 100, 1)                        AS pct_organically_loyal,
    ROUND(AVG(Brand_Commitment_Score), 3)                 AS avg_brand_commitment,

    -- Revenue at Stake
    ROUND(AVG(spend), 2)                                  AS avg_spend_usd,
    ROUND(AVG(repeat_purchases), 2)                       AS avg_repeat_purchases,
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,

    -- ── Promotional Strategy Recommendation ───────────────────────────
    CASE
        WHEN AVG(is_loyal) >= 0.6
         AND AVG(used_promo) < 0.3                        THEN 'Safe to Sunset Promos'
        WHEN AVG(is_loyal) >= 0.4
         AND AVG(used_promo) BETWEEN 0.3 AND 0.6          THEN 'Gradual Phase-Down Suitable'
        WHEN AVG(is_loyal) BETWEEN 0.2 AND 0.5
         AND AVG(used_promo) > 0.5                        THEN 'Handle with Care — Transition Needed'
        WHEN AVG(is_loyal) < 0.2
         AND AVG(used_promo) > 0.5                        THEN 'Promo-Dependent — Volume Risk if Cut'
        ELSE                                                    'Monitor and Re-Evaluate'
    END                                                   AS promo_strategy_recommendation

FROM promo_segments
GROUP BY segment, behavior_profile
ORDER BY pct_promo_used DESC, avg_ltv_score DESC;


-- =====================================================
-- QUERY 4B
-- PROMO SUNSET CANDIDATE IDENTIFICATION
-- Customers who are Loyal AND Promo-Heavy (Transition Targets)
-- =====================================================
-- WHAT IT MEASURES:
--   Counts how many customers already show loyalty signals yet still
--   receive discounts — meaning promos are redundant for them and
--   can be removed first with minimal churn risk.
-- HOW TO INTERPRET:
--   These are promo sunset quick wins. Remove discounts from
--   this group first; their loyalty suggests they will re-purchase anyway.
-- DASHBOARD RELEVANCE:
--   Promo optimisation targeting list.

SELECT
    segment,
    lifetime_value_tier,

    -- Promo sunset candidates: loyal but still getting promos
    SUM(CASE
        WHEN is_loyal_behavioral = 1
         AND (Discount_Applied_Enc = 1 OR Promo_Code_Used_Enc = 1)
        THEN 1 ELSE 0
    END)                                                   AS promo_sunset_candidates,

    -- Customers already promo-free and loyal (the gold standard)
    SUM(CASE
        WHEN is_loyal_behavioral = 1
         AND Discount_Applied_Enc = 0
         AND Promo_Code_Used_Enc  = 0
        THEN 1 ELSE 0
    END)                                                   AS promo_free_loyal,

    -- Promo-dependent, low loyalty (highest churn risk if promos removed)
    SUM(CASE
        WHEN is_loyal_behavioral = 0
         AND Discount_Applied_Enc = 1
         AND Promo_Code_Used_Enc  = 1
        THEN 1 ELSE 0
    END)                                                   AS high_churn_risk_if_promo_removed,

    COUNT(*)                                               AS total_in_segment,

    ROUND(AVG(`Purchase Amount (USD)`), 2)                 AS avg_spend_usd,
    ROUND(AVG(Brand_Commitment_Score), 3)                  AS avg_brand_commitment

FROM customer_features
GROUP BY segment, lifetime_value_tier
ORDER BY promo_sunset_candidates DESC, lifetime_value_tier;


-- =====================================================
-- QUERY 4C
-- PROMO STRATEGY IMPACT SIMULATION
-- Projected Revenue at Risk vs Protected by Segment
-- =====================================================
-- WHAT IT MEASURES:
--   Estimates the revenue volume tied to promo-dependent customers
--   and how much is "protected" by organic loyalty — informing how
--   aggressively promos can be cut without damaging topline revenue.
-- HOW TO INTERPRET:
--   High "protected_revenue_usd" and low "at_risk_revenue_usd" in a
--   segment = safe zone for promo reduction.
-- DASHBOARD RELEVANCE:
--   Revenue exposure model for commercial strategy review.

SELECT
    segment,
    COUNT(*)                                              AS total_customers,

    -- Revenue attached to promo-dependent, non-loyal customers (at risk)
    SUM(CASE
        WHEN is_loyal_behavioral = 0
         AND Discount_Applied_Enc = 1
        THEN `Purchase Amount (USD)` ELSE 0
    END)                                                   AS at_risk_revenue_usd,

    -- Revenue attached to loyal customers regardless of promo status
    SUM(CASE
        WHEN is_loyal_behavioral = 1
        THEN `Purchase Amount (USD)` ELSE 0
    END)                                                   AS protected_revenue_usd,

    -- Total segment revenue
    SUM(`Purchase Amount (USD)`)                           AS total_segment_revenue_usd,

    -- At-risk as percentage of segment total
    ROUND(
        SUM(CASE WHEN is_loyal_behavioral = 0 AND Discount_Applied_Enc = 1
            THEN `Purchase Amount (USD)` ELSE 0 END)
        * 100.0
        / NULLIF(SUM(`Purchase Amount (USD)`), 0),
    1)                                                     AS pct_revenue_at_risk

FROM customer_features
GROUP BY segment
ORDER BY pct_revenue_at_risk DESC;


-- =====================================================
-- QUERY 5
-- BUSINESS QUESTION: WHAT DOES THE BRAND'S IDEAL
-- CUSTOMER PROFILE LOOK LIKE?
-- Ideal Customer Profile Construction — Top LTV Cohort
-- =====================================================
-- WHAT IT MEASURES:
--   Profiles the top LTV / highest-commitment customers across all
--   demographic, geographic, behavioural, and commercial dimensions.
-- HOW TO INTERPRET:
--   The output represents the modal characteristics of the brand's
--   highest-value, lowest-promo-dependency customers. This is the
--   acquisition and retention blueprint.
-- DASHBOARD RELEVANCE:
--   Ideal Customer Profile (ICP) summary card for marketing and brand strategy.

WITH ideal_customers AS (
    SELECT *
    FROM customer_features
    WHERE lifetime_value_tier = 'High'
      AND is_loyal_behavioral  = 1
      AND Discount_Applied_Enc = 0
      AND Promo_Code_Used_Enc  = 0
),

icp_summary AS (
    SELECT
        -- Demographics
        ROUND(AVG(Age), 1)                                AS avg_age,

        -- Gender split
        SUM(CASE WHEN Gender = 'Male'   THEN 1 ELSE 0 END) AS male_count,
        SUM(CASE WHEN Gender = 'Female' THEN 1 ELSE 0 END) AS female_count,

        -- Commercial Profile
        ROUND(AVG(`Purchase Amount (USD)`), 2)            AS avg_spend_usd,
        ROUND(AVG(`Previous Purchases`), 2)               AS avg_prev_purchases,
        ROUND(AVG(`Review Rating`), 2)                    AS avg_rating,
        ROUND(AVG(lifetime_val_score), 4)                 AS avg_ltv_score,
        ROUND(AVG(Brand_Commitment_Score), 4)             AS avg_brand_commitment,
        ROUND(AVG(freq_score), 1)                         AS avg_freq_score,

        -- Subscription
        ROUND(AVG(Subscription_Status_Enc) * 100, 1)      AS pct_subscribers,

        COUNT(*)                                           AS total_ideal_customers
    FROM ideal_customers
)

SELECT
    total_ideal_customers,
    avg_age,

    -- Gender Distribution
    male_count,
    female_count,
    ROUND(male_count   * 100.0 / total_ideal_customers, 1) AS pct_male,
    ROUND(female_count * 100.0 / total_ideal_customers, 1) AS pct_female,

    -- Commercial
    avg_spend_usd,
    avg_prev_purchases,
    avg_rating,
    avg_ltv_score,
    avg_brand_commitment,
    avg_freq_score,
    pct_subscribers
FROM icp_summary;


-- =====================================================
-- QUERY 5B
-- IDEAL CUSTOMER PROFILE — TOP CATEGORIES, SEASONS,
-- AGE BANDS, AND GEOGRAPHIES
-- =====================================================
-- WHAT IT MEASURES:
--   Identifies which categories, seasons, age groups, and states
--   are most represented within the ideal customer cohort.
-- HOW TO INTERPRET:
--   Top-ranked values in each dimension define the brand's target profile.
--   Use for channel planning, creative strategy, and geo-expansion.
-- DASHBOARD RELEVANCE:
--   ICP Breakdown panels — each dimension is a chart input.

-- Top Categories
SELECT
    'Category'                                            AS dimension,
    Category                                              AS dimension_value,
    COUNT(*)                                              AS ideal_customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1)    AS pct_of_ideal_cohort,
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd
FROM customer_features
WHERE lifetime_value_tier = 'High'
  AND is_loyal_behavioral  = 1
  AND Discount_Applied_Enc = 0
  AND Promo_Code_Used_Enc  = 0
GROUP BY Category
ORDER BY ideal_customer_count DESC

UNION ALL

-- Top Seasons
SELECT
    'Season'                                              AS dimension,
    Season                                                AS dimension_value,
    COUNT(*)                                              AS ideal_customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1)    AS pct_of_ideal_cohort,
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd
FROM customer_features
WHERE lifetime_value_tier = 'High'
  AND is_loyal_behavioral  = 1
  AND Discount_Applied_Enc = 0
  AND Promo_Code_Used_Enc  = 0
GROUP BY Season
ORDER BY ideal_customer_count DESC

UNION ALL

-- Top Age Bands
SELECT
    'Age Band'                                            AS dimension,
    age_band                                              AS dimension_value,
    COUNT(*)                                              AS ideal_customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1)    AS pct_of_ideal_cohort,
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd
FROM customer_features
WHERE lifetime_value_tier = 'High'
  AND is_loyal_behavioral  = 1
  AND Discount_Applied_Enc = 0
  AND Promo_Code_Used_Enc  = 0
GROUP BY age_band
ORDER BY ideal_customer_count DESC;


-- =====================================================
-- QUERY 5C
-- IDEAL CUSTOMER PROFILE — TOP 10 STATES
-- =====================================================
SELECT
    Location                                              AS state,
    COUNT(*)                                              AS ideal_customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1)    AS pct_of_ideal_cohort,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd,
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,
    ROUND(AVG(Brand_Commitment_Score), 3)                 AS avg_brand_commitment
FROM customer_features
WHERE lifetime_value_tier = 'High'
  AND is_loyal_behavioral  = 1
  AND Discount_Applied_Enc = 0
  AND Promo_Code_Used_Enc  = 0
GROUP BY Location
ORDER BY ideal_customer_count DESC
LIMIT 10;


-- =====================================================
-- QUERY 6A
-- ADDITIONAL ANALYSIS: HIGH-VALUE vs LOW-VALUE CUSTOMERS
-- What Separates Them? — Full Differentiator Breakdown
-- =====================================================
-- WHAT IT MEASURES:
--   Side-by-side comparison of High LTV vs Low LTV vs Risk tier across
--   every available loyalty, behavioural, demographic, and promo dimension.
-- HOW TO INTERPRET:
--   Columns with the largest absolute gap between High and Risk rows
--   are the strongest commercial differentiators.
--   Rank manually by eyeing which metrics have the widest spread.
-- DASHBOARD RELEVANCE:
--   Customer value comparison table for leadership review.

SELECT
    lifetime_value_tier                                   AS ltv_tier,

    COUNT(*)                                              AS customer_count,

    -- ── Repeat Purchase Behaviour ─────────────────────────────────────
    ROUND(AVG(`Previous Purchases`), 2)                   AS avg_prev_purchases,
    ROUND(MAX(`Previous Purchases`), 0)                   AS max_prev_purchases,

    -- ── Spend ─────────────────────────────────────────────────────────
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd,
    ROUND(SUM(`Purchase Amount (USD)`), 0)                AS total_revenue_usd,

    -- ── Loyalty ───────────────────────────────────────────────────────
    ROUND(AVG(is_loyal_behavioral) * 100, 1)              AS pct_organically_loyal,
    ROUND(AVG(Brand_Commitment_Score), 4)                 AS avg_brand_commitment,

    -- ── Promo Dependency ──────────────────────────────────────────────
    ROUND(AVG(Discount_Applied_Enc) * 100, 1)             AS pct_discount_used,
    ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)             AS pct_promo_used,

    -- ── Subscription ──────────────────────────────────────────────────
    ROUND(AVG(Subscription_Status_Enc) * 100, 1)          AS pct_subscribers,

    -- ── Satisfaction ──────────────────────────────────────────────────
    ROUND(AVG(`Review Rating`), 2)                        AS avg_rating,
    ROUND(AVG(Satisfaction_Flag) * 100, 1)                AS pct_satisfied,

    -- ── Purchase Frequency ────────────────────────────────────────────
    ROUND(AVG(freq_score), 2)                             AS avg_freq_score,

    -- ── Urgency ───────────────────────────────────────────────────────
    ROUND(AVG(Urgency_Score), 2)                          AS avg_urgency_score,

    -- ── Customer Segment Distribution ────────────────────────────────
    ROUND(SUM(CASE WHEN segment = 'Premium Loyalists'  THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                          AS pct_premium_loyalists,
    ROUND(SUM(CASE WHEN segment = 'Organic High-Value' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                          AS pct_organic_high_value,
    ROUND(SUM(CASE WHEN segment = 'Promo-Driven Buyers' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 1)                          AS pct_promo_driven

FROM customer_features
GROUP BY lifetime_value_tier
ORDER BY FIELD(lifetime_value_tier, 'High', 'Normal', 'Low', 'Risk');


-- =====================================================
-- QUERY 6B
-- STRONGEST REPEAT PURCHASE PROFILES
-- Which Customer Profiles Exhibit the Strongest
-- Repeat Purchase Behaviour?
-- =====================================================
-- WHAT IT MEASURES:
--   Ranks customer segment x behaviour profile combinations by
--   average previous purchases and repeat purchase intensity.
-- HOW TO INTERPRET:
--   Top rows are the strongest retention cohorts. These are the
--   archetypes to replicate through acquisition and nurture programs.
-- DASHBOARD RELEVANCE:
--   Repeat purchase leaderboard / retention cohort panel.

SELECT
    segment,
    Customer_Behavior_Profile                             AS behavior_archetype,
    lifetime_value_tier,
    COUNT(*)                                              AS customer_count,

    -- Repeat Purchase Metrics
    ROUND(AVG(`Previous Purchases`), 2)                   AS avg_prev_purchases,
    ROUND(MAX(`Previous Purchases`), 0)                   AS max_prev_purchases,
    ROUND(MIN(`Previous Purchases`), 0)                   AS min_prev_purchases,

    -- Supporting Signals
    ROUND(AVG(freq_score), 2)                             AS avg_freq_score,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd,
    ROUND(AVG(Brand_Commitment_Score), 3)                 AS avg_brand_commitment,
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,

    -- Rank by repeat purchase volume
    RANK() OVER (ORDER BY AVG(`Previous Purchases`) DESC) AS repeat_purchase_rank

FROM customer_features
GROUP BY segment, Customer_Behavior_Profile, lifetime_value_tier
ORDER BY avg_prev_purchases DESC;


-- =====================================================
-- QUERY 7A
-- ADDITIONAL ANALYSIS: CATEGORY AND SEASON ANALYSIS
-- Which Categories Attract Lower vs Higher Tenure Customers?
-- =====================================================
-- WHAT IT MEASURES:
--   Average previous purchases, LTV, promo dependency, and loyalty
--   broken down by product category. Previous Purchases is used as
--   a proxy for customer tenure and long-term engagement.
-- HOW TO INTERPRET:
--   Higher avg_prev_purchases = category attracts longer-tenure customers.
--   Lower = category skews toward new or transient buyers.
-- DASHBOARD RELEVANCE:
--   Category health panel — tenure and retention by product line.

SELECT
    Category,
    COUNT(*)                                              AS transaction_count,

    -- Tenure Proxy
    ROUND(AVG(`Previous Purchases`), 2)                   AS avg_prev_purchases,
    ROUND(MIN(`Previous Purchases`), 0)                   AS min_prev_purchases,
    ROUND(MAX(`Previous Purchases`), 0)                   AS max_prev_purchases,

    -- Spend
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd,

    -- Loyalty
    ROUND(AVG(is_loyal_behavioral) * 100, 1)              AS pct_loyal,
    ROUND(AVG(Brand_Commitment_Score), 3)                 AS avg_brand_commitment,

    -- Promo Dependency
    ROUND(AVG(Discount_Applied_Enc) * 100, 1)             AS pct_discount_used,
    ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)             AS pct_promo_used,

    -- LTV
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,

    -- Tenure Classification
    CASE
        WHEN AVG(`Previous Purchases`) >= 28 THEN 'High Tenure Category'
        WHEN AVG(`Previous Purchases`) >= 24 THEN 'Medium Tenure Category'
        ELSE                                       'Low Tenure Category'
    END                                                   AS tenure_classification,

    -- Rank by tenure
    RANK() OVER (ORDER BY AVG(`Previous Purchases`) DESC) AS tenure_rank

FROM customer_features
GROUP BY Category
ORDER BY avg_prev_purchases DESC;


-- =====================================================
-- QUERY 7B
-- SEASON ANALYSIS
-- Which Seasons Are Associated with Strongest
-- Repeat Purchasing and Retention?
-- =====================================================
-- WHAT IT MEASURES:
--   Compares repeat purchase volume, LTV, loyalty, and promo dependency
--   across all four seasons to identify the strongest retention windows.
-- HOW TO INTERPRET:
--   Season with highest avg_prev_purchases AND highest pct_loyal is the
--   most retention-positive season. Prioritise loyalty programs here.
-- DASHBOARD RELEVANCE:
--   Seasonal retention curve / campaign timing optimisation.

SELECT
    Season,
    COUNT(*)                                              AS transaction_count,

    -- Repeat Purchasing
    ROUND(AVG(`Previous Purchases`), 2)                   AS avg_prev_purchases,

    -- Spend
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd,
    ROUND(SUM(`Purchase Amount (USD)`), 0)                AS total_revenue_usd,

    -- Loyalty
    ROUND(AVG(is_loyal_behavioral) * 100, 1)              AS pct_loyal,
    ROUND(AVG(Brand_Commitment_Score), 3)                 AS avg_brand_commitment,

    -- Promo Dependency
    ROUND(AVG(Discount_Applied_Enc) * 100, 1)             AS pct_discount_used,
    ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)             AS pct_promo_used,

    -- LTV
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,

    -- Satisfaction
    ROUND(AVG(`Review Rating`), 2)                        AS avg_rating,

    -- Season Rank by Repeat Purchase Strength
    RANK() OVER (ORDER BY AVG(`Previous Purchases`) DESC) AS repeat_purchase_rank,
    RANK() OVER (ORDER BY AVG(is_loyal_behavioral) DESC)  AS loyalty_rank

FROM customer_features
GROUP BY Season
ORDER BY avg_prev_purchases DESC;


-- =====================================================
-- QUERY 7C
-- CATEGORY x SEASON COMBINATION ANALYSIS
-- Which Category-Season Combos Are Most Strongly
-- Linked to Customer Retention?
-- =====================================================
-- WHAT IT MEASURES:
--   Cross-tabs category and season to find the best-performing
--   intersections for repeat purchasing and LTV contribution.
-- HOW TO INTERPRET:
--   The top-ranked combinations are natural retention windows
--   where the right product meets the right buying moment.
--   Promotional calendars and loyalty activations should be
--   anchored to these intersections.
-- DASHBOARD RELEVANCE:
--   Category x Season retention matrix — heat map input.

SELECT
    Category,
    Season,
    COUNT(*)                                              AS transaction_count,

    -- Retention Signals
    ROUND(AVG(`Previous Purchases`), 2)                   AS avg_prev_purchases,
    ROUND(AVG(is_loyal_behavioral) * 100, 1)              AS pct_loyal,

    -- Spend
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_usd,

    -- LTV
    ROUND(AVG(lifetime_val_score), 3)                     AS avg_ltv_score,

    -- Promo Dependency
    ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)             AS pct_promo_used,

    -- Composite Retention Score: blend tenure + loyalty
    ROUND(
        (AVG(`Previous Purchases`) / 50.0) * 0.5
        + AVG(is_loyal_behavioral)          * 0.3
        + AVG(lifetime_val_score)           * 0.2,
    4)                                                     AS composite_retention_score,

    -- Rank within each Category
    RANK() OVER (
        PARTITION BY Category
        ORDER BY AVG(`Previous Purchases`) DESC
    )                                                      AS season_rank_within_category

FROM customer_features
GROUP BY Category, Season
ORDER BY composite_retention_score DESC;


-- =====================================================
-- QUERY 8
-- GEOGRAPHY: ORGANIC DEMAND vs DISCOUNT-DRIVEN DEMAND
-- Dashboard-Ready Location Classification
-- =====================================================
-- WHAT IT MEASURES:
--   Classifies every US state into one of four commercial demand
--   archetypes using average spend vs promo dependency thresholds.
--   Identifies markets for premium positioning, acquisition, promo
--   optimisation, and retention investment.
-- HOW TO INTERPRET:
--   - Organic Demand (High Spend + Low Promo)     → Premium positioning / brand investment
--   - Discount-Driven Volume (High Spend + High Promo) → Promo optimisation / margin recovery
--   - Underleveraged Market (Low Spend + Low Promo) → Customer acquisition opportunity
--   - Promo-Dependent Weak Market (Low Spend + High Promo) → Deprioritise or restructure
-- DASHBOARD RELEVANCE:
--   State-level geo classification map — primary geographic strategy view.

WITH geo_aggregates AS (
    SELECT
        Location                                          AS state,
        COUNT(*)                                          AS customer_count,
        ROUND(AVG(`Purchase Amount (USD)`), 2)            AS avg_spend_usd,
        ROUND(SUM(`Purchase Amount (USD)`), 0)            AS total_revenue_usd,
        ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)         AS pct_promo_used,
        ROUND(AVG(Discount_Applied_Enc) * 100, 1)         AS pct_discount_used,
        ROUND(AVG(is_loyal_behavioral)  * 100, 1)         AS pct_loyal,
        ROUND(AVG(lifetime_val_score), 3)                 AS avg_ltv_score,
        ROUND(AVG(Brand_Commitment_Score), 3)             AS avg_brand_commitment,
        ROUND(AVG(`Review Rating`), 2)                    AS avg_rating,
        ROUND(AVG(`Previous Purchases`), 2)               AS avg_prev_purchases
    FROM customer_features
    GROUP BY Location
),

-- Global thresholds (used in CASE logic for consistent classification)
thresholds AS (
    SELECT
        AVG(avg_spend_usd)  AS spend_threshold,
        AVG(pct_promo_used) AS promo_threshold
    FROM geo_aggregates
)

SELECT
    ga.state,
    ga.customer_count,
    ga.avg_spend_usd,
    ga.total_revenue_usd,
    ga.pct_promo_used,
    ga.pct_discount_used,
    ga.pct_loyal,
    ga.avg_ltv_score,
    ga.avg_brand_commitment,
    ga.avg_rating,
    ga.avg_prev_purchases,

    -- ── Primary Geo Classification ─────────────────────────────────
    CASE
        WHEN ga.avg_spend_usd >= t.spend_threshold
         AND ga.pct_promo_used < t.promo_threshold
        THEN 'High Spend + Low Promo Dependency — Organic Demand'

        WHEN ga.avg_spend_usd >= t.spend_threshold
         AND ga.pct_promo_used >= t.promo_threshold
        THEN 'High Spend + High Promo Dependency — Discount-Driven Volume'

        WHEN ga.avg_spend_usd < t.spend_threshold
         AND ga.pct_promo_used < t.promo_threshold
        THEN 'Low Spend + Low Promo Dependency — Underleveraged Market'

        ELSE
            'Low Spend + High Promo Dependency — Weak / Promo-Reliant'
    END                                                   AS geo_demand_archetype,

    -- ── Strategic Recommendation ───────────────────────────────────
    CASE
        WHEN ga.avg_spend_usd >= t.spend_threshold
         AND ga.pct_promo_used < t.promo_threshold
        THEN 'Premium Positioning — Scale Brand Investment'

        WHEN ga.avg_spend_usd >= t.spend_threshold
         AND ga.pct_promo_used >= t.promo_threshold
        THEN 'Promo Optimisation — Protect Volume, Recover Margin'

        WHEN ga.avg_spend_usd < t.spend_threshold
         AND ga.pct_promo_used < t.promo_threshold
        THEN 'Customer Acquisition — Low Promo Sensitivity = Organic Growth Possible'

        ELSE
            'Deprioritise or Restructure — Low Value, High Promo Cost'
    END                                                   AS strategic_recommendation

FROM geo_aggregates ga
CROSS JOIN thresholds t
ORDER BY
    CASE
        WHEN ga.avg_spend_usd >= t.spend_threshold AND ga.pct_promo_used < t.promo_threshold  THEN 1
        WHEN ga.avg_spend_usd >= t.spend_threshold AND ga.pct_promo_used >= t.promo_threshold THEN 2
        WHEN ga.avg_spend_usd < t.spend_threshold  AND ga.pct_promo_used < t.promo_threshold  THEN 3
        ELSE 4
    END,
    ga.avg_ltv_score DESC;


-- =====================================================
-- QUERY 9
-- EXECUTIVE SUMMARY VIEW
-- Brand Health Scorecard — Single-Glance KPIs
-- =====================================================
-- WHAT IT MEASURES:
--   A single-row executive summary of the entire customer base across
--   the key health metrics. Designed for C-suite dashboards and
--   top-of-deck context in strategy reviews.
-- HOW TO INTERPRET:
--   Benchmark each metric against industry standards or prior periods.
--   The promo dependency rate and organic loyalty rate together define
--   the brand's structural health.
-- DASHBOARD RELEVANCE:
--   Top-level KPI summary card — first view on the analytics dashboard.

SELECT
    -- Volume
    COUNT(*)                                              AS total_customers,
    ROUND(SUM(`Purchase Amount (USD)`), 0)                AS total_revenue_usd,
    ROUND(AVG(`Purchase Amount (USD)`), 2)                AS avg_spend_per_customer_usd,

    -- Loyalty Health
    ROUND(AVG(is_loyal_behavioral) * 100, 1)              AS pct_organically_loyal,
    ROUND(AVG(Brand_Commitment_Score), 3)                 AS avg_brand_commitment_score,
    ROUND(AVG(Subscription_Status_Enc) * 100, 1)          AS pct_subscribers,

    -- Promo Dependency (risk indicator)
    ROUND(AVG(Discount_Applied_Enc) * 100, 1)             AS pct_customers_using_discount,
    ROUND(AVG(Promo_Code_Used_Enc)  * 100, 1)             AS pct_customers_using_promo,

    -- LTV Health
    ROUND(AVG(lifetime_val_score), 4)                     AS avg_ltv_score,
    ROUND(AVG(`Previous Purchases`), 2)                   AS avg_purchase_history_depth,

    -- Satisfaction
    ROUND(AVG(`Review Rating`), 2)                        AS avg_satisfaction_rating,
    ROUND(AVG(Satisfaction_Flag) * 100, 1)                AS pct_satisfied_customers,

    -- Frequency
    ROUND(AVG(freq_score), 2)                             AS avg_frequency_score,

    -- Segment Composition
    ROUND(SUM(CASE WHEN segment = 'Premium Loyalists'   THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_premium_loyalists,
    ROUND(SUM(CASE WHEN segment = 'Organic High-Value'  THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_organic_high_value,
    ROUND(SUM(CASE WHEN segment = 'Growth Customers'    THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_growth_customers,
    ROUND(SUM(CASE WHEN segment = 'Promo-Driven Buyers' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_promo_driven_buyers

FROM customer_features;

-- =====================================================================================================================================
-- END OF SCRIPT: customer_retention_analysis.sql
-- 9 major query blocks | 14 individual queries
-- All outputs are dashboard-ready and directly support the 5 business
-- questions, high-value analysis, category/season analysis, and
-- geographic demand classification.
-- =====================================================================================================================================
