SELECT DISTINCT VendorID
FROM `kestra-demo-449917.ny_taxi.yellow_tripdata_non_partitoned`
WHERE tpep_dropoff_datetime BETWEEN '2024-03-01' AND '2024-03-15';
