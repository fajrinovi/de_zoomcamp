SELECT 
    'Materialized Table' AS Table_Type, 
    COUNT(DISTINCT PULocationID) AS Unique_PULocationIDs 
FROM `kestra-demo-449917.ny_taxi.yellow_tripdata_non_partitoned`;