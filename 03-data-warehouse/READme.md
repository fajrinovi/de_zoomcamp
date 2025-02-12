## Module 3 Homework

<b><u>Important Note:</b></u> <p> For this homework we will be using the Yellow Taxi Trip Records for **January 2024 - June 2024 NOT the entire year of data** 
Parquet Files from the New York
City Taxi Data found here: </br> https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page </br>
If you are using orchestration such as Kestra, Mage, Airflow or Prefect etc. do not load the data into Big Query using the orchestrator.</br> 
Stop with loading the files into a bucket. </br></br>

<u>NOTE:</u> You will need to use the PARQUET option files when creating an External Table</br>

<b>BIG QUERY SETUP:</b></br>
Upload parquet files to the bucket
![Screenshot 2025-02-12 074009](https://github.com/user-attachments/assets/b3ec1c83-dbfa-42d8-aab8-acf4a0106ecd)

Create an external table using the Yellow Taxi Trip Records. </br>
![Screenshot 2025-02-11 220115](https://github.com/user-attachments/assets/423c920f-c5ee-462a-a310-a11c95340650)

Create a (regular/materialized) table in BQ using the Yellow Taxi Trip Records (do not partition or cluster this table). </br>
![Screenshot 2025-02-12 074349](https://github.com/user-attachments/assets/f7880285-3866-4d16-b3b5-793e2d1343f6)


</p>

## Question 1:
Question 1: What is count of records for the 2024 Yellow Taxi Data?
- 65,623
- 840,402
- 20,332,093
- 85,431,289

Solution:
```sql
SELECT count(1) FROM `kestra-demo-449917.ny_taxi.external_yellow_tripdata` ;
```
![Screenshot 2025-02-12 074921](https://github.com/user-attachments/assets/732b96d8-1ffe-4226-90b6-f6962e67a32b)

Answer:
```
20,332,093
```

## Question 2:
Write a query to count the distinct number of PULocationIDs for the entire dataset on both the tables.</br> 
What is the **estimated amount** of data that will be read when this query is executed on the External Table and the Table?

- 18.82 MB for the External Table and 47.60 MB for the Materialized Table
- 0 MB for the External Table and 155.12 MB for the Materialized Table
- 2.14 GB for the External Table and 0MB for the Materialized Table
- 0 MB for the External Table and 0MB for the Materialized Table

Solution:
External Table:
![Screenshot 2025-02-12 222408](https://github.com/user-attachments/assets/622fb923-e2c6-49e7-a6bf-8366e3c63080)

Materialized Table
![Screenshot 2025-02-12 222321](https://github.com/user-attachments/assets/674ed282-6e34-4309-b904-55aa3064875b)

Answer:
```
0 MB for the External Table and 155.12 MB for the Materialized Table
```

## Question 3:
Write a query to retrieve the PULocationID from the table (not the external table) in BigQuery. Now write a query to retrieve the PULocationID and DOLocationID on the same table. Why are the estimated number of Bytes different?
- BigQuery is a columnar database, and it only scans the specific columns requested in the query. Querying two columns (PULocationID, DOLocationID) requires 
reading more data than querying one column (PULocationID), leading to a higher estimated number of bytes processed.
- BigQuery duplicates data across multiple storage partitions, so selecting two columns instead of one requires scanning the table twice, 
doubling the estimated bytes processed.
- BigQuery automatically caches the first queried column, so adding a second column increases processing time but does not affect the estimated bytes scanned.
- When selecting multiple columns, BigQuery performs an implicit join operation between them, increasing the estimated bytes processed

Solution:
![Screenshot 2025-02-12 225605](https://github.com/user-attachments/assets/cd885d25-f295-426a-ad34-9c41fbf8816e)
![Screenshot 2025-02-12 225618](https://github.com/user-attachments/assets/e9690fc3-37f2-4a91-bb54-a7c19f3d0d49)

the estimated number of Bytes different

Answer:
```
BigQuery is a columnar database, and it only scans the specific columns requested in the query. Querying two columns (PULocationID, DOLocationID) requires 
reading more data than querying one column (PULocationID), leading to a higher estimated number of bytes processed.
```

## Question 4:
How many records have a fare_amount of 0?
- 128,210
- 546,578
- 20,188,016
- 8,333

Solution:
![Screenshot 2025-02-12 230040](https://github.com/user-attachments/assets/08884f9a-f891-4639-a446-5614398978ca)

Answer:
```
8,333
```  

## Question 5:
What is the best strategy to make an optimized table in Big Query if your query will always filter based on tpep_dropoff_datetime and order the results by VendorID (Create a new table with this strategy)
- Partition by tpep_dropoff_datetime and Cluster on VendorID
- Cluster on by tpep_dropoff_datetime and Cluster on VendorID
- Cluster on tpep_dropoff_datetime Partition by VendorID
- Partition by tpep_dropoff_datetime and Partition by VendorID

Solution:
Partitioning by tpep_dropoff_datetime

Since queries filter by tpep_dropoff_datetime, partitioning ensures that BigQuery scans only the relevant partitions, reducing data scanned.
Using DATE(tpep_dropoff_datetime) instead of TIMESTAMP reduces the number of partitions.

Clustering on VendorID

Since queries order by VendorID, clustering groups similar VendorID values together within partitions.
This speeds up sorting and filtering on VendorID by reducing the amount of data BigQuery needs to sort.

```sql
CREATE OR REPLACE TABLE `kestra-demo-449917.ny_taxi.optimized_yellow_tripdata`
PARTITION BY DATE(tpep_dropoff_datetime)
CLUSTER BY VendorID AS
SELECT * FROM `kestra-demo-449917.ny_taxi.yellow_tripdata_non_partitoned`;
```

![Screenshot 2025-02-12 232012](https://github.com/user-attachments/assets/0927a8f2-0bdd-41d2-8b65-c7053303fcaa)

Answer:
```
Partition by tpep_dropoff_datetime and Cluster on VendorID
```

## Question 6:
Write a query to retrieve the distinct VendorIDs between tpep_dropoff_datetime
2024-03-01 and 2024-03-15 (inclusive)</br>

Use the materialized table you created earlier in your from clause and note the estimated bytes. Now change the table in the from clause to the partitioned table you created for question 5 and note the estimated bytes processed. What are these values? </br>

Choose the answer which most closely matches.</br> 

- 12.47 MB for non-partitioned table and 326.42 MB for the partitioned table
- 310.24 MB for non-partitioned table and 26.84 MB for the partitioned table
- 5.87 MB for non-partitioned table and 0 MB for the partitioned table
- 310.31 MB for non-partitioned table and 285.64 MB for the partitioned table


Solution:
non-partitioned table
```sql
SELECT DISTINCT VendorID
FROM `kestra-demo-449917.ny_taxi.yellow_tripdata_non_partitoned`
WHERE tpep_dropoff_datetime BETWEEN '2024-03-01' AND '2024-03-15';
```
![Screenshot 2025-02-12 232724](https://github.com/user-attachments/assets/2b664d40-98ee-4189-ad38-f5b462a72b92)


partitioned
```sql
SELECT DISTINCT VendorID
FROM `kestra-demo-449917.ny_taxi.optimized_yellow_tripdata`
WHERE tpep_dropoff_datetime BETWEEN '2024-03-01' AND '2024-03-15';
```
![Screenshot 2025-02-12 232734](https://github.com/user-attachments/assets/80915c8c-3113-4c3f-b921-b9d76cc85d74)

Answer:
```
310.24 MB for non-partitioned table and 26.84 MB for the partitioned table
```


## Question 7: 
Where is the data stored in the External Table you created?

- Big Query
- Container Registry
- GCP Bucket
- Big Table

Answer:
```
GCP Bucket
```
 The data is not stored inside BigQuery. Instead, it remains in Google Cloud Storage (GCS) at: `gs://yellow_tripdate_2024/*`

## Question 8:
It is best practice in Big Query to always cluster your data:
- True
- False

Answer:
```
False
```

While clustering in BigQuery can improve query performance and reduce scanned data, it is not always the best practice for every table. Clustering should only be used when beneficial for specific query patterns

When to Use Clustering?
✔ Queries frequently filter or sort by a specific column (e.g., VendorID).
✔ Large tables (millions+ rows) where clustering reduces scanned data.
✔ Already using partitioning but need additional optimization.

When Not to Use Clustering?
❌ Small tables → Queries run fast without clustering.
❌ Queries don’t often filter/sort by the clustered column → No real benefit.
❌ Frequent updates or inserts → Clustering slows performance as data needs reorganization.


## (Bonus: Not worth points) Question 9:
No Points: Write a `SELECT count(*)` query FROM the materialized table you created. How many bytes does it estimate will be read? Why?

Answer:
```sql
SELECT COUNT(*) 
FROM `kestra-demo-449917.ny_taxi.yellow_tripdata_non_partitoned`;
```
![Screenshot 2025-02-12 234159](https://github.com/user-attachments/assets/17822182-11d6-4fce-b5a5-b7de5cd68a65)

BigQuery optimizes COUNT(*) for materialized tables using precomputed metadata, so no full table scan is needed.
