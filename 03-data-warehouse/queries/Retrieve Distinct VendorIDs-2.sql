SELECT DISTINCT VendorID
FROM `kestra-demo-449917.ny_taxi.optimized_yellow_tripdata`
WHERE tpep_dropoff_datetime BETWEEN '2024-03-01' AND '2024-03-15';
