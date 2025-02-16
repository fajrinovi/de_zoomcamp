Original file is located at
    https://colab.research.google.com/drive/1plqdl33K_HkVx0E0nGJrrkEUssStQsW7

# **Workshop "Data Ingestion with dlt": Homework**

---

## **Dataset & API**

We’ll use **NYC Taxi data** via the same custom API from the workshop:

🔹 **Base API URL:**  
```
https://us-central1-dlthub-analytics.cloudfunctions.net/data_engineering_zoomcamp_api
```
🔹 **Data format:** Paginated JSON (1,000 records per page).  
🔹 **API Pagination:** Stop when an empty page is returned.

## **Question 1: dlt Version**

1. **Install dlt**:

```
!pip install dlt[duckdb]
```

2. **Check** the version:

```
!dlt --version
```

or:

```py
import dlt
print("dlt version:", dlt.__version__)
```

Answer: 
```
dlt 1.6.1
```

## **Question 2: Define & Run the Pipeline (NYC Taxi API)**

Use dlt to extract all pages of data from the API.

Steps:

1️⃣ Use the `@dlt.resource` decorator to define the API source.

2️⃣ Implement automatic pagination using dlt's built-in REST client.

3️⃣ Load the extracted data into DuckDB for querying.

```py

import dlt
from dlt.sources.helpers.rest_client import RESTClient
from dlt.sources.helpers.rest_client.paginators import PageNumberPaginator
import duckdb


# Use the @dlt.resource decorator to define the API source. Implement automatic pagination
@dlt.resource(name="rides") 
def ny_taxi():
    client = RESTClient(
        base_url="https://us-central1-dlthub-analytics.cloudfunctions.net",
        paginator=PageNumberPaginator(
            base_page=1,
            total_path=None
        )
    )

    for page in client.paginate("data_engineering_zoomcamp_api"):    # <--- API endpoint for retrieving taxi ride data
        yield page   # <--- yield data to manage memory


# define new dlt pipeline
pipeline = dlt.pipeline(
    pipeline_name="ny_taxi_pipeline",
    destination="duckdb",
    dataset_name="ny_taxi_data"
)

# Load the extracted data into DuckDB for querying.
load_info = pipeline.run(ny_taxi, write_disposition="replace")

# Connect to the DuckDB database
conn = duckdb.connect(f"{pipeline.pipeline_name}.duckdb")

# Set search path to the dataset
conn.sql(f"SET search_path = '{pipeline.dataset_name}'")

# Describe the dataset and load it into a Pandas DataFrame
df = conn.sql("DESCRIBE").df()

# Display the DataFrame
print(df)

```

How many tables were created?

* 2
* 4
* 6
* 8

Answer:
4 tables
```
           database        schema                 name                                       column_names                                       column_types  temporary
0  ny_taxi_pipeline  ny_taxi_data           _dlt_loads  [load_id, schema_name, status, inserted_at, sc...  [VARCHAR, VARCHAR, BIGINT, TIMESTAMP WITH TIME...      False
1  ny_taxi_pipeline  ny_taxi_data  _dlt_pipeline_state  [version, engine_version, pipeline_name, state...  [BIGINT, BIGINT, VARCHAR, VARCHAR, TIMESTAMP W...      False
2  ny_taxi_pipeline  ny_taxi_data         _dlt_version  [version, engine_version, inserted_at, schema_...  [BIGINT, BIGINT, TIMESTAMP WITH TIME ZONE, VAR...      False
3  ny_taxi_pipeline  ny_taxi_data                rides  [end_lat, end_lon, fare_amt, passenger_count, ...  [DOUBLE, DOUBLE, DOUBLE, BIGINT, VARCHAR, DOUB...      False
```

## **Question 3: Explore the loaded data**

Inspect the table `ride`:

```py
df = pipeline.dataset(dataset_type="default").rides.df()
df
```

What is the total number of records extracted?

* 2500
* 5000
* 7500
* 10000

Answer:
10000
```
<class 'pandas.core.frame.DataFrame'>
RangeIndex: 10000 entries, 0 to 9999
Data columns (total 18 columns):
```

## **Question 4: Trip Duration Analysis**

Run the SQL query below to:

* Calculate the average trip duration in minutes.

```py
with pipeline.sql_client() as client:
    res = client.execute_sql(
            """
            SELECT
            AVG(date_diff('minute', trip_pickup_date_time, trip_dropoff_date_time))
            FROM rides;
            """
        )
    # Prints column values of the first row
    print(res)
```

What is the average trip duration?

* 12.3049
* 22.3049
* 32.3049
* 42.3049

Answer:
```
[(12.3049,)]
```

