# Google Ads Performance Benchmarking

This BigQuery script generates a comparative analysis table that evaluates current year Google Ads performance against historical averages for the same calendar day (Month/Day).

## Overview

* **Target Table:** `upland-farm.summary_tables.gads_cpa_vs_hist_avg`

* **Source Data:** `upland-farm.google_ads_data_transfer.p_ads_AccountBasicStats_9578934950`

* **Primary Goal:** To provide context for daily performance by answering: *"How does today's performance compare to every other time we've seen this specific date in the past?"*

## Script Logic & Workflow

The script executes in five distinct phases:

1. **Dynamic Parameters (`params`):** Automatically identifies the current year and date boundaries to ensure the script remains dynamic as time progresses.

2. **Raw Data Extraction (`daily_stats`):**

   * Aggregates metrics from the Google Ads Data Transfer service.

   * Converts `metrics_cost_micros` to standard currency values (dividing by $1,000,000$).

   * Extracts Year, Month, and Day for granular joining.

3. **Historical Benchmarking (`benchmarks`):**

   * Groups data by **Month** and **Day** (ignoring the year).

   * Calculates **Average**, **Minimum**, and **Maximum** for CPA, ROAS, Revenue, and Cost.

   * This creates a "seasonal baseline" for every day of the calendar year.

4. **Ranking Pool (`ranking_pool`):**

   * Calculates the performance rank for every day in history relative to its specific calendar date.

   * **CPA Rank:** Ascending (Lower cost per acquisition is better).

   * **ROAS/Revenue Rank:** Descending (Higher values are better).

5. **Final Comparative Join:**

   * Joins the `ranking_pool` for the **current year** back to the `benchmarks` baseline.

   * Uses a `CROSS JOIN` on parameters to strictly filter for the current year's data.

## Key Metrics Tracked

| **Metric** | **Calculation Logic** | **Ranking Priority** | 
| :--- | :--- | :--- |
| **CPA** | `SAFE_DIVIDE(cost, conversions)` | Rank 1 = Lowest CPA | 
| **ROAS** | `SAFE_DIVIDE(revenue, cost)` | Rank 1 = Highest ROAS | 
| **Revenue** | `SUM(revenue)` | Rank 1 = Highest Revenue | 
| **Cost** | `SUM(cost)` | Rank 1 = Highest Spend | 

## 🗄 Output Schema

| **Column** | **Description** | 
| :--- | :--- |
| `date` | The specific date within the current year. | 
| `current_...` | The actual performance recorded for that date. | 
| `..._avg` | The historical mean for that specific Month/Day. | 
| `..._min` | The all-time "floor" for that specific Month/Day. | 
| `..._max` | The all-time "ceiling" for that specific Month/Day. | 
| `..._rank` | Where the current day stands in historical context. | 

## ⚠️ Implementation Notes

* **Safety First:** The script utilizes `SAFE_DIVIDE` to prevent errors on days where conversions or costs are zero.

* **Micros:** Ensure any updates to the source data maintain the micros format (10^6), or the currency calculations will be off.

* **Cross Join:** The final `CROSS JOIN` is intentionally used to inject dynamic date parameters into the filter without requiring hard-coded strings.
