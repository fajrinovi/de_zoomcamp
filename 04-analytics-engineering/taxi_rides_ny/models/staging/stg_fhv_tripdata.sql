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