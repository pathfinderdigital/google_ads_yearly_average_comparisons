/*******************************************************************************
  GOOGLE ADS PERFORMANCE BENCHMARKING SCRIPT (PLATFORM-ONLY)
  
  DATA SOURCE: This script pulls data EXCLUSIVELY from Google Ads datasets. 
  
  FIX NOTE: We use a CROSS JOIN for the current year to ensure we compare 
  today's performance against ALL historical matching dates independently.
*******************************************************************************/

CREATE OR REPLACE TABLE
  `upland-farm.summary_tables.gads_cpa_vs_hist_avg` AS

WITH params AS (
    -- 1. DYNAMIC DATE PARAMETERS
    SELECT
      DATE_TRUNC(CURRENT_DATE(), YEAR) AS current_year_start,
      DATE_ADD(DATE_TRUNC(CURRENT_DATE(), YEAR), INTERVAL 1 YEAR) AS current_year_end,
      EXTRACT(YEAR FROM CURRENT_DATE()) AS current_year
),

daily_stats AS (
    -- 2. RAW DATA EXTRACTION & AGGREGATION
    -- We aggregate everything first to make joins cleaner.
    SELECT
      segments_date AS date,
      EXTRACT(MONTH FROM segments_date) AS m,
      EXTRACT(DAY FROM segments_date) AS d,
      EXTRACT(YEAR FROM segments_date) AS y,
      SUM(metrics_cost_micros / 1e6) AS cost,
      SUM(metrics_conversions) AS convs,
      SUM(metrics_conversions_value) AS revenue
    FROM `upland-farm.google_ads_data_transfer.p_ads_AccountBasicStats_9578934950`
    GROUP BY 1, 2, 3, 4
),

benchmarks AS (
    -- 3. HISTORICAL POOL GENERATION
    -- We create a table of averages/min/max for every Month/Day combo in history
    -- INCLUDING the current year data.
    SELECT
      m,
      d,
      -- CPA Benchmarks
      AVG(SAFE_DIVIDE(cost, convs)) AS cpa_avg,
      MIN(SAFE_DIVIDE(cost, convs)) AS cpa_min,
      MAX(SAFE_DIVIDE(cost, convs)) AS cpa_max,
      -- ROAS Benchmarks
      AVG(SAFE_DIVIDE(revenue, cost)) AS roas_avg,
      MIN(SAFE_DIVIDE(revenue, cost)) AS roas_min,
      MAX(SAFE_DIVIDE(revenue, cost)) AS roas_max,
      -- Revenue Benchmarks
      AVG(revenue) AS revenue_avg,
      MIN(revenue) AS revenue_min,
      MAX(revenue) AS revenue_max,
      -- Cost Benchmarks
      AVG(cost) AS cost_avg,
      MIN(cost) AS cost_min,
      MAX(cost) AS cost_max
    FROM daily_stats
    GROUP BY m, d
),

ranking_pool AS (
    -- 4. PREPARING RANKINGS
    -- We need the raw historical values to calculate the rank of the current day
    SELECT 
      date, m, d, y, cost, convs, revenue,
      SAFE_DIVIDE(cost, convs) as cpa,
      SAFE_DIVIDE(revenue, cost) as roas,
      RANK() OVER(PARTITION BY m, d ORDER BY SAFE_DIVIDE(cost, convs) ASC) as cpa_rank,
      RANK() OVER(PARTITION BY m, d ORDER BY SAFE_DIVIDE(revenue, cost) DESC) as roas_rank,
      RANK() OVER(PARTITION BY m, d ORDER BY revenue DESC) as revenue_rank,
      RANK() OVER(PARTITION BY m, d ORDER BY cost DESC) as cost_rank
    FROM daily_stats
)

-- 5. FINAL JOIN
-- We join the stats from the CURRENT YEAR to the BENCHMARKS calculated from ALL years.
SELECT
  curr.date,
  
  -- CPA
  ROUND(curr.cpa, 2) AS current_cpa,
  ROUND(b.cpa_avg, 2) AS cpa_avg,
  ROUND(b.cpa_min, 2) AS cpa_min,
  ROUND(b.cpa_max, 2) AS cpa_max,
  curr.cpa_rank,
  
  -- ROAS
  ROUND(curr.roas, 4) AS current_roas,
  ROUND(b.roas_avg, 4) AS roas_avg,
  ROUND(b.roas_min, 4) AS roas_min,
  ROUND(b.roas_max, 4) AS roas_max,
  curr.roas_rank,
  
  -- Revenue
  ROUND(curr.revenue, 2) AS current_revenue,
  ROUND(b.revenue_avg, 2) AS revenue_avg,
  ROUND(b.revenue_min, 2) AS revenue_min,
  ROUND(b.revenue_max, 2) AS revenue_max,
  curr.revenue_rank,
  
  -- Cost
  ROUND(curr.cost, 2) AS current_cost,
  ROUND(b.cost_avg, 2) AS cost_avg,
  ROUND(b.cost_min, 2) AS cost_min,
  ROUND(b.cost_max, 2) AS cost_max,
  curr.cost_rank

FROM ranking_pool curr
JOIN benchmarks b ON curr.m = b.m AND curr.d = b.d
CROSS JOIN params p
WHERE curr.y = p.current_year
ORDER BY curr.date;
