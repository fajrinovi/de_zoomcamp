SELECT 
    'External Table' AS Table_Type, 
    COUNT(DISTINCT PULocationID) AS Unique_PULocationIDs 
FROM `kestra-demo-449917.ny_taxi.external_yellow_tripdata`;