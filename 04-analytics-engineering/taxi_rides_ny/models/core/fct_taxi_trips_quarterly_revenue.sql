{{
    config(
        materialized = 'table'
    )
}}

WITH agg_trips AS (
  SELECT 
    EXTRACT(YEAR FROM pickup_datetime) AS pickup_year,
    EXTRACT(QUARTER FROM pickup_datetime) AS pickup_quarter,
    CONCAT(EXTRACT(YEAR FROM pickup_datetime), '/Q', EXTRACT(QUARTER FROM pickup_datetime)) AS year_quarter,
    service_type,
    SUM(total_amount) AS quarterly_revenue
  FROM {{ ref('fact_trips') }}
  WHERE EXTRACT(YEAR FROM pickup_datetime) BETWEEN 2019 AND 2020
  GROUP BY 1,2,3,4
)

, quarterly_yoy_revenue AS (
  SELECT 
    pickup_year,
    pickup_quarter,
    year_quarter,
    service_type,
    quarterly_revenue,
    LAG(quarterly_revenue, 1) OVER(PARTITION BY service_type, pickup_quarter ORDER BY pickup_year) AS last_quarterly_revenue,
    LAG(year_quarter, 1) OVER(PARTITION BY service_type, pickup_quarter ORDER BY pickup_year) AS last_quarterly_revenue_year_quarter
  FROM agg_trips
)

SELECT *
FROM quarterly_yoy_revenue
