## Overview

This BigQuery SQL script processes raw Google Ads account data to create a comparative performance baseline for every calendar day. It transforms historical campaign statistics into a structured summary table that answers the critical question: "How does today's performance compare to every other time we've seen this specific date in the past?"

## Key Features

* Seasonal Baselines: Automatically groups historical data by Month and Day (ignoring the year) to create a "seasonal baseline" for every day of the calendar year.
* Multi-Metric Benchmarking: Calculates a comprehensive suite of statistics including Average, Minimum, and Maximum values for CPA, ROAS, Revenue, and Cost.
* Historical Performance Ranking: Utilizes window functions to rank the current year's performance against all historical data points for that same calendar date.
* Dynamic Date Context: Automatically identifies the current year and date boundaries, ensuring the comparisons remain relevant as time progresses without manual intervention.
* Performance Optimized: * Uses SAFE_DIVIDE to prevent errors on days where conversions or costs are zero.

** Aggregates raw data into a daily_stats CTE to ensure cleaner joins and reduced processing overhead.
** Employs a CROSS JOIN for dynamic parameter injection, avoiding hard-coded date strings.

## How to Customize

To deploy this in a new Google Cloud project, update the following two areas marked in the code:

### Destination Table:
Update `upland-farm.summary_tables.gads_cpa_vs_hist_avg` to your specific ProjectID.Dataset.TableName.

### Source Data:
Update `upland-farm.google_ads_data_transfer.p_ads_AccountBasicStats_9578934950` to point to your raw Google Ads Data Transfer service table.

## Output Schema

The resulting table provides the following columns:

* date: The specific date within the current year being analyzed.
* current_...: The actual performance recorded for that date (CPA, ROAS, Revenue, Cost).
* ..._avg: The historical mean for that specific Month/Day across all years.
* ..._min / ..._max: The all-time "floor" and "ceiling" for that specific Month/Day.
* ..._rank: A numerical rank showing where the current day stands in historical context.

## Data Quality: Performance Ranking Logic

To provide context for daily performance, the script evaluates where the current year sits relative to history. This allows marketers to identify if a "high" CPA is actually a historical improvement or a genuine outlier.

## The Methodology

The script applies a specific ranking priority to each metric using window functions. Instead of a "one-size-fits-all" sort, it prioritizes based on marketing goals:

* Efficiency (CPA): Uses ASC ranking. Because a lower cost per acquisition is better, Rank 1 represents the lowest (best) historical CPA for that date.
* Returns (ROAS & Revenue): Uses DESC ranking. Higher values are prioritized, meaning Rank 1 represents the highest historical performance.
* Investment (Cost): Uses DESC ranking to identify days of peak investment relative to historical spending patterns.

## Why this is necessary

* Contextual Accuracy: A high CPA on a holiday like Black Friday might be alarming in isolation, but "Rank 1" status indicates it is actually the most efficient Black Friday in the account's history.
* Seasonality Awareness: Traditional averages (e.g., Last 30 Days) often ignore annual seasonality. This script ensures that a Tuesday in December is only compared to other Tuesdays in December.
* Dashboard Readiness: By pre-calculating ranks and benchmarks, you can build Looker Studio reports that instantly flag performance anomalies without complex client-side calculations.
