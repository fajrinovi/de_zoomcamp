# Module 1 Homework: Docker & SQL

In this homework I'll prepare the environment and practice
Docker and SQL

## Question 1. Understanding docker first run 

Run docker with the `python:3.12.8` image in an interactive mode, use the entrypoint `bash`.

What's the version of `pip` in the image?

- 24.3.1
- 24.2.1
- 23.3.1
- 23.2.1

### Solution:
1. Run this in the terminal `docker run -it --entrypoint=bash python:3.12.8`
2. Next, run this to check the version `pip --version`

![pip version](https://github.com/user-attachments/assets/14fea450-5a01-4a53-918e-99637b5c0a53)

#### Output:
```
24.3.1
```
## Question 2. Understanding Docker networking and docker-compose

Given the following `docker-compose.yaml`, what is the `hostname` and `port` that **pgadmin** should use to connect to the postgres database?

```yaml
services:
  db:
    container_name: postgres
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: 'postgres'
      POSTGRES_PASSWORD: 'postgres'
      POSTGRES_DB: 'ny_taxi'
    ports:
      - '5433:5432'
    volumes:
      - vol-pgdata:/var/lib/postgresql/data

  pgadmin:
    container_name: pgadmin
    image: dpage/pgadmin4:latest
    environment:
      PGADMIN_DEFAULT_EMAIL: "pgadmin@pgadmin.com"
      PGADMIN_DEFAULT_PASSWORD: "pgadmin"
    ports:
      - "8080:80"![pip version](https://github.com/user-attachments/assets/7cac64e2-2a32-49f7-bbcf-7326838937d9)

    volumes:
      - vol-pgadmin_data:/var/lib/pgadmin  

volumes:
  vol-pgdata:
    name: vol-pgdata
  vol-pgadmin_data:
    name: vol-pgadmin_data
```

- postgres:5433
- localhost:5432
- db:5433
- postgres:5432
- db:5432

If there are more than one answers, select only one of them

Solution:

The PostgreSQL container (named db) listens on port 5432 internally, but it's mapped to port 5433 on local machine. When connecting from pgadmin (which is in the same Docker network), you should use db as the hostname and port 5432. From outside Docker (like local machine), you would use localhost:5433 to connect to PostgreSQL

Answer:
```
db:5432
```

##  Prepare Postgres

Run the ingestion for green taxi

```bash
URL=https://github.com/DataTalksClub/nyc-tlc-data/releases/download/green/green_tripdata_2019-10.csv.gz
docker run -it \
    --network=homework-1  \
    data_ingest:home_work \
        --user=postgres \
        --pass=postgres \
        --host=postgres \
        --port=5432 \
        --db=ny_taxi \
        --table_name=green_taxi_trips \
        --url=${URL}
```

Run the ingestion for zones

```bash
URL=https://github.com/DataTalksClub/nyc-tlc-data/releases/download/misc/taxi_zone_lookup.csv
docker run -it \
    --network=homework-1 \
    data_ingest:home_work \
        --user=postgres \
        --pass=postgres \
        --host=postgres \
        --port=5432 \
        --db=ny_taxi \
        --table_name=zones \
        --url=${URL}
```


## Question 3. Trip Segmentation Count

During the period of October 1st 2019 (inclusive) and November 1st 2019 (exclusive), how many trips, **respectively**, happened:
1. Up to 1 mile
2. In between 1 (exclusive) and 3 miles (inclusive),
3. In between 3 (exclusive) and 7 miles (inclusive),
4. In between 7 (exclusive) and 10 miles (inclusive),
5. Over 10 miles 

Answers:

- 104,802;  197,670;  110,612;  27,831;  35,281
- 104,802;  198,924;  109,603;  27,678;  35,189
- 104,793;  201,407;  110,612;  27,831;  35,281
- 104,793;  202,661;  109,603;  27,678;  35,189
- 104,838;  199,013;  109,645;  27,688;  35,202

### Solution:
Run this query:
```sql
SELECT 
    trip_distance, 
    COUNT(1)
FROM (
    SELECT 
        CASE 
            WHEN trip_distance <= 1 THEN 'Up to 1 mile' 
            WHEN trip_distance > 1 AND trip_distance <= 3 THEN '1-3'
            WHEN trip_distance > 3 AND trip_distance <= 7 THEN '3-7'
            WHEN trip_distance > 7 AND trip_distance <= 10 THEN '7-10'
            WHEN trip_distance > 10 THEN 'Over 10'
        END as trip_distance
    FROM green_taxi_trips 
    WHERE
        DATE(lpep_dropoff_datetime) >= '2019-10-01' AND 
        DATE(lpep_dropoff_datetime) < '2019-11-01'
) AS categorized_trip
GROUP BY trip_distance;
```
Output:
| trip_distance    | count         | 
|------------------|---------------|
| 1-3              | 198924        | 
| 3-7              | 109603        |
| 7-10             | 27678         |
| Over 10          | 35189         |
| Up to 1 mile     | 104802        |

Answer:
```
104,802;  198,924;  109,603;  27,678;  35,189
```

## Question 4. Longest trip for each day

Which was the pick up day with the longest trip distance?
Use the pick up time for your calculations.

Tip: For every day, we only care about one single trip with the longest distance. 

- 2019-10-11
- 2019-10-24
- 2019-10-26
- 2019-10-31

### Solution:
Run this query
```sql
SELECT 
    DATE(lpep_pickup_datetime) AS pickup_date,
    trip_distance
FROM green_taxi_trips
WHERE trip_distance = (
    SELECT MAX(trip_distance)
    FROM green_taxi_trips
)
LIMIT 1;
```

Output:
| pickup_date    | trip_distance  | 
|----------------|----------------|
| 2019-10-31     | 515.89         |

Answer:
```
2019-10-31
```

## Question 5. Three biggest pickup zones

Which were the top pickup locations with over 13,000 in
`total_amount` (across all trips) for 2019-10-18?

Consider only `lpep_pickup_datetime` when filtering by date.
 
- East Harlem North, East Harlem South, Morningside Heights
- East Harlem North, Morningside Heights
- Morningside Heights, Astoria Park, East Harlem South
- Bedford, East Harlem North, Astoria Park

### Solution
Run this query:
```sql
SELECT 
    z."Zone" AS pickup_zone,
    SUM(g.total_amount) AS total_amount
FROM 
    green_taxi_trips AS g
    JOIN zones AS z 
    ON g."PULocationID" = z."LocationID"
WHERE 
    DATE(g.lpep_pickup_datetime) = '2019-10-18'
GROUP BY 
    z."Zone"
HAVING 
    SUM(g.total_amount) > 13000
ORDER BY 
    total_amount DESC;
```

Output:
| pickup_zone            | total_amount         | 
|------------------------|----------------------|
| East Harlem North      | 18686.680000000084   | 
| East Harlem South      | 16797.260000000068   |
| Morningside Heights    | 13029.790000000028   |

Answer:
```
East Harlem North, East Harlem South, Morningside Heights
```

## Question 6. Largest tip

For the passengers picked up in October 2019 in the zone
named "East Harlem North" which was the drop off zone that had
the largest tip?

Note: it's `tip` , not `trip`

We need the name of the zone, not the ID.

- Yorkville West
- JFK Airport
- East Harlem North
- East Harlem South

### Solution:
Run this query:
```sql
SELECT 
    z_dropoff."Zone" AS dropoff_zone, 
    MAX(g.tip_amount) AS max_tip
FROM 
    green_taxi_trips AS g
    JOIN zones AS z_pickup 
        ON g."PULocationID" = z_pickup."LocationID"
    JOIN zones AS z_dropoff 
        ON g."DOLocationID" = z_dropoff."LocationID"
WHERE 
    z_pickup."Zone" = 'East Harlem North'
    AND DATE(g.lpep_pickup_datetime) >= '2019-10-01'
    AND DATE(g.lpep_pickup_datetime) < '2019-11-01'
GROUP BY 
    z_dropoff."Zone"
ORDER BY 
    max_tip DESC
LIMIT 1;
```

Output:
| dropoff_zone     | max_tip    | 
|------------------|------------|
| JFK Airport      | 87.3       |

Answer:
```
JFK Airport
```

## Terraform

Setting Up
1. IAM Service Account
    Download and install [Google Cloud CLI](https://cloud.google.com/sdk/docs/install-sdk) for your platform, following the instructions on the page.
    On the GCP Console, create a new Service Account with the roles of: Bigquery Admin, Storage Admin, Compute Admin
    Next, access the created service_account, and create a 'New Key' with Key type: JSON, and save it somewhere safe on your workstation
    ![service account](https://github.com/user-attachments/assets/990c0823-1ca8-48b0-b3ed-7f1ad6303a03)
    ![Untitled design](https://github.com/user-attachments/assets/96a8478f-762d-4862-8902-5d85b466f614)

    Now, export the environment variables GOOGLE_APPLICATION_CREDENTIALS pointing to the full path where the .json credentials file was downloaded/saved:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/gcp-credentials.json
   ```
    verify authentification
   ```bash
   gcloud auth application-default login 
   ```
2. Initialize Terraform:
    Navigate to the directory with Terraform files, update project details (e.g., bucket name must be unique), and run
   ```bash
   terraform init
   ```
   ```bash
   terraform plan //Optional, to check what apply does
   ```
   ```bash
   terraform apply --auto-approve
   ```
3. Clean Up Resources:
  To avoid incurring costs for running services, delete the infrastructure when you’re done
   ```bash
    terraform destroy
   ```

## Question 7. Terraform Workflow

Which of the following sequences, **respectively**, describes the workflow for: 
1. Downloading the provider plugins and setting up backend,
2. Generating proposed changes and auto-executing the plan
3. Remove all resources managed by terraform`

Answers:
- terraform import, terraform apply -y, terraform destroy
- teraform init, terraform plan -auto-apply, terraform rm
- terraform init, terraform run -auto-approve, terraform destroy
- terraform init, terraform apply -auto-approve, terraform destroy
- terraform import, terraform apply -y, terraform rm

Answer:
```
terraform init, terraform apply -auto-approve, terraform destroy
```
