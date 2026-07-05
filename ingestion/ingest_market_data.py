"""Hourly CoinGecko snapshot -> BigQuery.

Sandbox-safe by design: uses a batch LOAD job (streaming inserts are not
allowed in the BigQuery Sandbox). Append-only; dedup happens downstream in
dbt (stg_market__stablecoin_prices) because Sandbox forbids MERGE.

Env vars:
  GCP_PROJECT_ID  - your Sandbox project id
"""

import os
from datetime import datetime, timezone

import requests
from google.cloud import bigquery

COINS = ["usd-coin", "tether"]
VS_CURRENCIES = ["usd", "php"]
TABLE_ID = "{project}.raw_market.stablecoin_prices"
COINGECKO_URL = "https://api.coingecko.com/api/v3/simple/price"

SCHEMA = [
    bigquery.SchemaField("coin_id", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("vs_currency", "STRING", mode="REQUIRED"),
    bigquery.SchemaField("price", "FLOAT64", mode="REQUIRED"),
    bigquery.SchemaField("fetched_at", "TIMESTAMP", mode="REQUIRED"),
]


def fetch_prices() -> list[dict]:
    resp = requests.get(
        COINGECKO_URL,
        params={"ids": ",".join(COINS), "vs_currencies": ",".join(VS_CURRENCIES)},
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    fetched_at = datetime.now(timezone.utc).isoformat()
    return [
        {"coin_id": coin, "vs_currency": cur, "price": price, "fetched_at": fetched_at}
        for coin, quotes in data.items()
        for cur, price in quotes.items()
    ]


def load_to_bigquery(rows: list[dict]) -> None:
    project = os.environ["GCP_PROJECT_ID"]
    client = bigquery.Client(project=project)
    table_id = TABLE_ID.format(project=project)

    # Create dataset/table on first run (idempotent)
    client.create_dataset("raw_market", exists_ok=True)
    client.create_table(bigquery.Table(table_id, schema=SCHEMA), exists_ok=True)

    job = client.load_table_from_json(
        rows,
        table_id,
        job_config=bigquery.LoadJobConfig(
            schema=SCHEMA,
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        ),
    )
    job.result()  # raises on failure
    print(f"Loaded {len(rows)} rows into {table_id}")


if __name__ == "__main__":
    load_to_bigquery(fetch_prices())
