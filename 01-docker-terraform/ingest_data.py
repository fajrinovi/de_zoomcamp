import pandas as pd
from sqlalchemy import create_engine
from time import time
import argparse
import os
import requests

def download_file(url, local_filename):
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(local_filename, 'wb') as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
    return local_filename

def main(params):
    user = params.user
    password = params.password
    host = params.host
    port = params.port
    db = params.db
    table_name = params.table_name
    url = params.url
    csv_name = "data.csv"

    if url.endswith('.csv.gz'):
        download_file(url, f"{csv_name}.gz")
        os.system(f"gzip -dv {csv_name}.gz")
    else:
        download_file(url, csv_name)

    connection_string = f"postgresql://{user}:{password}@{host}:{port}/{db}"
    engine = create_engine(connection_string)

    df_iter = pd.read_csv(csv_name, iterator=True, chunksize=100000)

    while True:
        t_start = time()
        try:
            df = next(df_iter)
        except StopIteration:
            break

        if table_name == 'green_taxi_trips':
            df.lpep_pickup_datetime = pd.to_datetime(df.lpep_pickup_datetime)
            df.lpep_dropoff_datetime = pd.to_datetime(df.lpep_dropoff_datetime)
        
        df.to_sql(name=table_name, con=engine, if_exists='append')
        t_end = time()

        print('Inserted chunk, took %.3f seconds' % (t_end - t_start))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Ingest data into postgres')
    parser.add_argument('--user', help='user for the postgres')
    parser.add_argument('--password', help='password for the postgres')
    parser.add_argument('--host', help='host for the postgres')
    parser.add_argument('--port', help='port for the postgres')
    parser.add_argument('--db', help='database name')
    parser.add_argument('--table_name', help='table name')
    parser.add_argument('--url', help='url of the csv')

    args = parser.parse_args()
    main(args)
