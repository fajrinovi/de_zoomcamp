SELECT COUNT(*) AS zero_fare_records
FROM `kestra-demo-449917.ny_taxi.yellow_tripdata_non_partitoned`
WHERE fare_amount = 0;