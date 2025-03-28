## Module 4 Homework

For this homework, you will need the following datasets:
* [Green Taxi dataset (2019 and 2020)](https://github.com/DataTalksClub/nyc-tlc-data/releases/tag/green)
* [Yellow Taxi dataset (2019 and 2020)](https://github.com/DataTalksClub/nyc-tlc-data/releases/tag/yellow)
* [For Hire Vehicle dataset (2019)](https://github.com/DataTalksClub/nyc-tlc-data/releases/tag/fhv)

### Before you start

1. Make sure you, **at least**, have them in GCS with a External Table **OR** a Native Table - use whichever method you prefer to accomplish that (Workflow Orchestration with [pandas-gbq](https://cloud.google.com/bigquery/docs/samples/bigquery-pandas-gbq-to-gbq-simple), [dlt for gcs](https://dlthub.com/docs/dlt-ecosystem/destinations/filesystem), [dlt for BigQuery](https://dlthub.com/docs/dlt-ecosystem/destinations/bigquery), [gsutil](https://cloud.google.com/storage/docs/gsutil), etc)

```sql
CREATE OR REPLACE EXTERNAL TABLE `de-zoomcamp-451605.ny_taxi.yellow_tripdata`
OPTIONS(
  FORMAT = 'CSV',
  uris = ['gs://taxi-rides-ny-2019-2020/yellow_tripdata_*.csv']
)

/* Create partitioned table from external table */
CREATE OR REPLACE TABLE `de-zoomcamp-451605.ny_taxi.yellow_tripdata_partitioned`
PARTITION BY DATE(tpep_pickup_datetime) 
CLUSTER BY VendorID
AS 
SELECT *
FROM `de-zoomcamp-451605.ny_taxi.yellow_tripdata`
;

CREATE OR REPLACE EXTERNAL TABLE `de-zoomcamp-451605.ny_taxi.green_tripdata`
OPTIONS(
  FORMAT = 'CSV',
  uris = ['gs://taxi-rides-ny-2019-2020/green_tripdata_*.csv']
)

/* Create partitioned table from external table */
CREATE OR REPLACE TABLE `de-zoomcamp-451605.ny_taxi.green_tripdata_partitioned`
PARTITION BY DATE(lpep_pickup_datetime) 
CLUSTER BY VendorID
AS 
SELECT *
FROM `de-zoomcamp-451605.ny_taxi.green_tripdata`
;
```


3. You should have exactly `7,778,101` records in your Green Taxi table
4. You should have exactly `109,047,518` records in your Yellow Taxi table
5. You should have exactly `43,244,696` records in your FHV table
6. Build the staging models for green/yellow as shown in [here](../../../04-analytics-engineering/taxi_rides_ny/models/staging/)
7. Build the dimension/fact for taxi_trips joining with `dim_zones`  as shown in [here](../../../04-analytics-engineering/taxi_rides_ny/models/core/fact_trips.sql)

**Note**: If you don't have access to GCP, you can spin up a local Postgres instance and ingest the datasets above


### Question 1: Understanding dbt model resolution

Provided you've got the following sources.yaml
```yaml
version: 2

sources:
  - name: raw_nyc_tripdata
    database: "{{ env_var('DBT_BIGQUERY_PROJECT', 'dtc_zoomcamp_2025') }}"
    schema:   "{{ env_var('DBT_BIGQUERY_SOURCE_DATASET', 'raw_nyc_tripdata') }}"
    tables:
      - name: ext_green_taxi
      - name: ext_yellow_taxi
```

with the following env variables setup where `dbt` runs:
```shell
export DBT_BIGQUERY_PROJECT=myproject
export DBT_BIGQUERY_DATASET=my_nyc_tripdata
```

What does this .sql model compile to?
```sql
select * 
from {{ source('raw_nyc_tripdata', 'ext_green_taxi' ) }}
```

- `select * from dtc_zoomcamp_2025.raw_nyc_tripdata.ext_green_taxi`
- `select * from dtc_zoomcamp_2025.my_nyc_tripdata.ext_green_taxi`
- `select * from myproject.raw_nyc_tripdata.ext_green_taxi`
- `select * from myproject.my_nyc_tripdata.ext_green_taxi`
- `select * from dtc_zoomcamp_2025.raw_nyc_tripdata.green_taxi`

Solution:

Sources in dbt: The source reference `{{ source('raw_nyc_tripdata', 'ext_green_taxi') }}` resolves to:
```pgsql
{database}.{schema}.{table}
```

where:

```
{database} → {{ env_var('DBT_BIGQUERY_PROJECT', 'dtc_zoomcamp_2025') }} → myproject
```
```
{schema} → {{ env_var('DBT_BIGQUERY_SOURCE_DATASET', 'raw_nyc_tripdata') }} → my_nyc_tripdata
```
```
{table} → ext_green_taxi
```

Answer:
```sql
select * from myproject.my_nyc_tripdata.ext_green_taxi
```

### Question 2: dbt Variables & Dynamic Models

Say you have to modify the following dbt_model (`fct_recent_taxi_trips.sql`) to enable Analytics Engineers to dynamically control the date range. 

- In development, you want to process only **the last 7 days of trips**
- In production, you need to process **the last 30 days** for analytics

```sql
select *
from {{ ref('fact_taxi_trips') }}
where pickup_datetime >= CURRENT_DATE - INTERVAL '30' DAY
```

What would you change to accomplish that in a such way that command line arguments takes precedence over ENV_VARs, which takes precedence over DEFAULT value?

- Add `ORDER BY pickup_datetime DESC` and `LIMIT {{ var("days_back", 30) }}`
- Update the WHERE clause to `pickup_datetime >= CURRENT_DATE - INTERVAL '{{ var("days_back", 30) }}' DAY`
- Update the WHERE clause to `pickup_datetime >= CURRENT_DATE - INTERVAL '{{ env_var("DAYS_BACK", "30") }}' DAY`
- Update the WHERE clause to `pickup_datetime >= CURRENT_DATE - INTERVAL '{{ var("days_back", env_var("DAYS_BACK", "30")) }}' DAY`
- Update the WHERE clause to `pickup_datetime >= CURRENT_DATE - INTERVAL '{{ env_var("DAYS_BACK", var("days_back", "30")) }}' DAY`

Answer:
```
Update the WHERE clause to pickup_datetime >= CURRENT_DATE - INTERVAL '{{ var("days_back", env_var("DAYS_BACK", "30")) }}' DAY
```

- var("days_back", env_var("DAYS_BACK", "30")):
- var("days_back") → First, it checks if a variable is passed via command-line (--vars '{"days_back": 7}').
- env_var("DAYS_BACK", "30") → If no command-line argument is provided, it falls back to an environment variable (DAYS_BACK).
Default (30) → If neither is provided, it defaults to 30

### Question 3: dbt Data Lineage and Execution

Considering the data lineage below **and** that taxi_zone_lookup is the **only** materialization build (from a .csv seed file):

<img width="1365" alt="homework_q2" src="https://github.com/user-attachments/assets/0bcdc78c-09dc-466b-879d-256ac325f48e" />

Select the option that does **NOT** apply for materializing `fct_taxi_monthly_zone_revenue`:

- `dbt run`
- `dbt run --select +models/core/dim_taxi_trips.sql+ --target prod`
- `dbt run --select +models/core/fct_taxi_monthly_zone_revenue.sql`
- `dbt run --select +models/core/`
- `dbt run --select models/staging/+`

Answer:
The option that does NOT apply for materializing fct_taxi_monthly_zone_revenue is:
```
dbt run --select models/staging/+
```

dbt run --select models/staging/+ only runs staging models and their dependencies but does not run fct_taxi_monthly_zone_revenue, which belongs to the core or marts layer.

### Question 4: dbt Macros and Jinja

Consider you're dealing with sensitive data (e.g.: [PII](https://en.wikipedia.org/wiki/Personal_data)), that is **only available to your team and very selected few individuals**, in the `raw layer` of your DWH (e.g: a specific BigQuery dataset or PostgreSQL schema), 

 - Among other things, you decide to obfuscate/masquerade that data through your staging models, and make it available in a different schema (a `staging layer`) for other Data/Analytics Engineers to explore

- And **optionally**, yet  another layer (`service layer`), where you'll build your dimension (`dim_`) and fact (`fct_`) tables (assuming the [Star Schema dimensional modeling](https://www.databricks.com/glossary/star-schema)) for Dashboarding and for Tech Product Owners/Managers

You decide to make a macro to wrap a logic around it:

```sql
{% macro resolve_schema_for(model_type) -%}

    {%- set target_env_var = 'DBT_BIGQUERY_TARGET_DATASET'  -%}
    {%- set stging_env_var = 'DBT_BIGQUERY_STAGING_DATASET' -%}

    {%- if model_type == 'core' -%} {{- env_var(target_env_var) -}}
    {%- else -%}                    {{- env_var(stging_env_var, env_var(target_env_var)) -}}
    {%- endif -%}

{%- endmacro %}
```

And use on your staging, dim_ and fact_ models as:
```sql
{{ config(
    schema=resolve_schema_for('core'), 
) }}
```

That all being said, regarding macro above, **select all statements that are true to the models using it**:
- Setting a value for  `DBT_BIGQUERY_TARGET_DATASET` env var is mandatory, or it'll fail to compile
- Setting a value for `DBT_BIGQUERY_STAGING_DATASET` env var is mandatory, or it'll fail to compile
- When using `core`, it materializes in the dataset defined in `DBT_BIGQUERY_TARGET_DATASET`
- When using `stg`, it materializes in the dataset defined in `DBT_BIGQUERY_STAGING_DATASET`, or defaults to `DBT_BIGQUERY_TARGET_DATASET`
- When using `staging`, it materializes in the dataset defined in `DBT_BIGQUERY_STAGING_DATASET`, or defaults to `DBT_BIGQUERY_TARGET_DATASET`


Answer:
- ✅ 1. Setting a value for `DBT_BIGQUERY_TARGET_DATASET` env var is mandatory, or it'll fail to compile
- ✅ 3. When using core, it materializes in the dataset defined in `DBT_BIGQUERY_TARGET_DATASET`
- ✅ 4. When using stg, it materializes in the dataset defined in `DBT_BIGQUERY_STAGING_DATASET`, or defaults to `DBT_BIGQUERY_TARGET_DATASET`
- ✅ 5. When using staging, it materializes in the dataset defined in `DBT_BIGQUERY_STAGING_DATASET`, or defaults to `DBT_BIGQUERY_TARGET_DATASET`

This statement is false:
- ❌ 2. Setting a value for `DBT_BIGQUERY_STAGING_DATASET` env var is mandatory, or it'll fail to compile (Karena kalau nggak ada, default-nya ke `DBT_BIGQUERY_TARGET_DATASET`).

## Serious SQL

Alright, in module 1, you had a SQL refresher, so now let's build on top of that with some serious SQL.

These are not meant to be easy - but they'll boost your SQL and Analytics skills to the next level.  
So, without any further do, let's get started...

You might want to add some new dimensions `year` (e.g.: 2019, 2020), `quarter` (1, 2, 3, 4), `year_quarter` (e.g.: `2019/Q1`, `2019-Q2`), and `month` (e.g.: 1, 2, ..., 12), **extracted from pickup_datetime**, to your `fct_taxi_trips` OR `dim_taxi_trips.sql` models to facilitate filtering your queries


### Question 5: Taxi Quarterly Revenue Growth

1. Create a new model `fct_taxi_trips_quarterly_revenue.sql`
2. Compute the Quarterly Revenues for each year for based on `total_amount`
3. Compute the Quarterly YoY (Year-over-Year) revenue growth 
  * e.g.: In 2020/Q1, Green Taxi had -12.34% revenue growth compared to 2019/Q1
  * e.g.: In 2020/Q4, Yellow Taxi had +34.56% revenue growth compared to 2019/Q4

Considering the YoY Growth in 2020, which were the yearly quarters with the best (or less worse) and worst results for green, and yellow

- green: {best: 2020/Q2, worst: 2020/Q1}, yellow: {best: 2020/Q2, worst: 2020/Q1}
- green: {best: 2020/Q2, worst: 2020/Q1}, yellow: {best: 2020/Q3, worst: 2020/Q4}
- green: {best: 2020/Q1, worst: 2020/Q2}, yellow: {best: 2020/Q2, worst: 2020/Q1}
- green: {best: 2020/Q1, worst: 2020/Q2}, yellow: {best: 2020/Q1, worst: 2020/Q2}
- green: {best: 2020/Q1, worst: 2020/Q2}, yellow: {best: 2020/Q3, worst: 2020/Q4}

Solution:
##### fct_taxi_trips_quarterly_revenue.sql
```sql
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
```


Answer:
- green: {best: 2020/Q1, worst: 2020/Q2}, yellow: {best: 2020/Q1, worst: 2020/Q2}
![Screenshot 2025-02-26 195236](https://github.com/user-attachments/assets/0b6d426e-d6ba-40f3-8eba-cc2358acf041)


### Question 6: P97/P95/P90 Taxi Monthly Fare

1. Create a new model `fct_taxi_trips_monthly_fare_p95.sql`
2. Filter out invalid entries (`fare_amount > 0`, `trip_distance > 0`, and `payment_type_description in ('Cash', 'Credit Card')`)
3. Compute the **continous percentile** of `fare_amount` partitioning by service_type, year and and month

Now, what are the values of `p97`, `p95`, `p90` for Green Taxi and Yellow Taxi, in April 2020?

- green: {p97: 55.0, p95: 45.0, p90: 26.5}, yellow: {p97: 52.0, p95: 37.0, p90: 25.5}
- green: {p97: 55.0, p95: 45.0, p90: 26.5}, yellow: {p97: 31.5, p95: 25.5, p90: 19.0}
- green: {p97: 40.0, p95: 33.0, p90: 24.5}, yellow: {p97: 52.0, p95: 37.0, p90: 25.5}
- green: {p97: 40.0, p95: 33.0, p90: 24.5}, yellow: {p97: 31.5, p95: 25.5, p90: 19.0}
- green: {p97: 55.0, p95: 45.0, p90: 26.5}, yellow: {p97: 52.0, p95: 25.5, p90: 19.0}

Solution:
##### fct_taxi_trips_monthly_fare_p95.sql
```sql

{{ config(materialized='table') }}

WITH valid_trips AS (
    SELECT
        service_type,
        EXTRACT(YEAR FROM pickup_datetime) AS year,
        EXTRACT(MONTH FROM pickup_datetime) AS month,
        fare_amount

    FROM {{ ref('fact_trips') }}
    WHERE 
        fare_amount > 0
        AND trip_distance > 0
        AND payment_type_description IN ('Cash', 'Credit card')
),

percentiles AS (
    SELECT 
        service_type,
        year,
        month,
        PERCENTILE_CONT(fare_amount, 0.97) OVER (PARTITION BY service_type, year, month) AS p97,
        PERCENTILE_CONT(fare_amount, 0.95) OVER (PARTITION BY service_type, year, month) AS p95,
        PERCENTILE_CONT(fare_amount, 0.90) OVER (PARTITION BY service_type, year, month) AS p90
    FROM valid_trips
    
)

SELECT * FROM percentiles
```

run this query:
```sql
SELECT DISTINCT service_type, year, month, p97, p95, p90 
FROM `de-zoomcamp-451605.ny_taxi.fct_taxi_trips_monthly_fare_p95`
WHERE month = 4 AND year = 2020;
```

Answer:
```
green: {p97: 55.0, p95: 45.0, p90: 26.5}, yellow: {p97: 31.5, p95: 25.5, p90: 19.0}
```

### Question 7: Top #Nth longest P90 travel time Location for FHV

Prerequisites:
* Create a staging model for FHV Data (2019), and **DO NOT** add a deduplication step, just filter out the entries where `where dispatching_base_num is not null`
* Create a core model for FHV Data (`dim_fhv_trips.sql`) joining with `dim_zones`. Similar to what has been done [here](../../../04-analytics-engineering/taxi_rides_ny/models/core/fact_trips.sql)
* Add some new dimensions `year` (e.g.: 2019) and `month` (e.g.: 1, 2, ..., 12), based on `pickup_datetime`, to the core model to facilitate filtering for your queries

Now...
1. Create a new model `fct_fhv_monthly_zone_traveltime_p90.sql`
2. For each record in `dim_fhv_trips.sql`, compute the [timestamp_diff](https://cloud.google.com/bigquery/docs/reference/standard-sql/timestamp_functions#timestamp_diff) in seconds between dropoff_datetime and pickup_datetime - we'll call it `trip_duration` for this exercise
3. Compute the **continous** `p90` of `trip_duration` partitioning by year, month, pickup_location_id, and dropoff_location_id

For the Trips that **respectively** started from `Newark Airport`, `SoHo`, and `Yorkville East`, in November 2019, what are **dropoff_zones** with the 2nd longest p90 trip_duration ?

- LaGuardia Airport, Chinatown, Garment District
- LaGuardia Airport, Park Slope, Clinton East
- LaGuardia Airport, Saint Albans, Howard Beach
- LaGuardia Airport, Rosedale, Bath Beach
- LaGuardia Airport, Yorkville East, Greenpoint

Solution:
##### stg_fhv_tripdata.sql
```sql
{{
    config(
        materialized='view'
    )
}}

WITH trip_data AS (
    SELECT 
      dispatching_base_num
    , pickup_datetime
    , dropOff_datetime
    , PUlocationID
    , DOlocationID
    , SR_Flag
    , Affiliated_base_number
    FROM {{ source('staging', 'fhv_tripdata_partitioned')}}
    WHERE 1=1
          AND dispatching_base_num IS NOT NULL
)

, renamed AS (
    SELECT 
    /* IDs */
      {{ dbt_utils.generate_surrogate_key(['dispatching_base_num', 'pickup_datetime', 'PUlocationID', 'dropOff_datetime', 'DOlocationID']) }} AS tripid
    , dispatching_base_num
    , PUlocationID AS pickup_locationid
    , DOlocationID AS dropoff_locationid
    , Affiliated_base_number AS affiliated_base_number

    /* Timestamps */
    , CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime
    , CAST(dropOff_datetime AS TIMESTAMP) AS dropoff_datetime 

    /* Details */
    , SR_Flag AS sr_flag
    FROM trip_data
)

SELECT *
FROM renamed

/* dbt build --select <model_name> --vars '{is_test_run': 'false'}' */
{% if var('is_test_run', default = True) %}

    LIMIT 100

{% endif %}
```
##### fact_fhv_trips.sql
```sql
{{
    config(
        materialized='table'
    )
}}

WITH trip_data AS (
    SELECT 
      fhv.tripid
    , fhv.dispatching_base_num
    , fhv.affiliated_base_number

    , fhv.pickup_locationid
    , pu_zones.borough AS pickup_borough
    , pu_zones.zone AS pickup_zone

    , fhv.dropoff_locationid
    , do_zones.borough AS dropoff_borough
    , do_zones.zone AS dropoff_zone

    /* Timestamps */
    , fhv.pickup_datetime
    , fhv.dropoff_datetime

    /* Date info */
    , EXTRACT(MONTH FROM fhv.pickup_datetime) AS pickup_month
    , CONCAT('Q', CAST(EXTRACT(QUARTER FROM fhv.pickup_datetime) AS STRING)) AS pickup_quarter
    , EXTRACT(YEAR FROM fhv.pickup_datetime) AS pickup_year

    /* Info */
    , fhv.sr_flag
    , 'fhv' AS service_type
    , ROW_NUMBER() OVER(PARTITION BY fhv.tripid ORDER BY fhv.pickup_datetime) AS r
    FROM {{ ref('stg_fhv_tripdata') }} fhv
    INNER JOIN {{ ref('dim_zones') }} AS pu_zones
      ON fhv.pickup_locationid = pu_zones.locationid AND pu_zones.borough != 'Unknown'
    INNER JOIN {{ ref('dim_zones') }} AS do_zones
      ON fhv.dropoff_locationid = do_zones.locationid AND do_zones.borough != 'Unknown'
)

SELECT *
FROM trip_data
WHERE 1=1
      AND r = 1
```
##### fact_fhv_monthly_zone_traveltime_p90.sql
```sql
{{
    config(
        materialized='table'
    )
}}

WITH fhv_trips AS (
  SELECT 
    pickup_year
  , pickup_month
  , pickup_locationid
  , pickup_zone
  , pickup_datetime
  , dropoff_locationid
  , dropoff_zone
  , dropoff_datetime
  , TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) AS trip_duration_sec
  FROM {{ ref('fact_fhv_trips') }}
)

, duration_percentiles AS (
  SELECT
    pickup_year
  , pickup_month
  , pickup_locationid
  , pickup_zone
  , pickup_datetime
  , dropoff_locationid
  , dropoff_zone
  , dropoff_datetime
  , trip_duration_sec
  , PERCENTILE_CONT(trip_duration_sec, 0.5) OVER(PARTITION BY pickup_year, pickup_month, pickup_locationid, dropoff_locationid) AS p50
  , PERCENTILE_CONT(trip_duration_sec, 0.9) OVER(PARTITION BY pickup_year, pickup_month, pickup_locationid, dropoff_locationid) AS p90
  , PERCENTILE_CONT(trip_duration_sec, 0.95) OVER(PARTITION BY pickup_year, pickup_month, pickup_locationid, dropoff_locationid) AS p95
  , PERCENTILE_CONT(trip_duration_sec, 0.97) OVER(PARTITION BY pickup_year, pickup_month, pickup_locationid, dropoff_locationid) AS p97 
  FROM fhv_trips
)

, final_data AS (
  SELECT 
    pickup_year
  , pickup_month
  , pickup_locationid
  , dropoff_locationid
  , pickup_zone
  , dropoff_zone 
  , COUNT(1) AS num_obs
  , MIN(trip_duration_sec) AS min_trip_duration_sec
  , AVG(trip_duration_sec) AS avg_trip_duration_sec
  , ANY_VALUE(p50) AS p50
  , ANY_VALUE(p90) AS p90
  , ANY_VALUE(p95) AS p95
  , ANY_VALUE(p97) AS p97
  , MAX(trip_duration_sec) AS max_trip_duration_sec
  FROM duration_percentiles
  GROUP BY 1,2,3,4,5,6
)

SELECT 
  pickup_year
, pickup_month
, pickup_zone
, dropoff_zone 
, num_obs
, min_trip_duration_sec
, avg_trip_duration_sec
, p50
, p90
, p95
, p97
, max_trip_duration_sec
FROM final_data 
WHERE 1=1
```

Run this query:
```sql

WITH ranked_data AS (
    SELECT 
        pickup_year
  , pickup_month
  , pickup_zone
  , dropoff_zone 
  , num_obs 
  , min_trip_duration_sec
  , avg_trip_duration_sec
  , p50
  , p90
  , p95
  , p97
  , max_trip_duration_sec
  , ROW_NUMBER() OVER(PARTITION BY pickup_Year, pickup_month, pickup_zone ORDER BY p90 DESC) AS p90_r_desc
  FROM `de-zoomcamp-451605.ny_taxi.fact_fhv_monthly_zone_traveltime_p90` 
  WHERE 1=1
        AND pickup_zone IN ('Newark Airport', 'SoHo', 'Yorkville East')
        AND pickup_year = 2019
        AND pickup_month = 11
)

SELECT DISTINCT 
    *
    
FROM ranked_data
WHERE p90_r_desc = 2;
```
Answer:
```
- LaGuardia Airport, Chinatown, Garment District
```
![Screenshot 2025-02-26 223809](https://github.com/user-attachments/assets/2c3df68a-a33f-4f36-80a6-a8ad94866745)

