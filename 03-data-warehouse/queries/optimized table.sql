CREATE OR REPLACE TABLE `kestra-demo-449917.ny_taxi.optimized_yellow_tripdata`
PARTITION BY DATE(tpep_dropoff_datetime)
CLUSTER BY VendorID AS
SELECT * FROM `kestra-demo-449917.ny_taxi.yellow_tripdata_non_partitoned`;