"""Validate generated CSVs and load them into a PostgreSQL database."""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text


DATA_DIR = Path(__file__).resolve().parents[1] / "data"
TABLES = ["customers", "products", "orders", "order_items", "payments", "returns"]
DATE_COLUMNS = {
    "customers": ["registered_at"],
    "orders": ["ordered_at"],
    "payments": ["paid_at"],
    "returns": ["returned_at"],
}


def read_table(table: str) -> pd.DataFrame:
    path = DATA_DIR / f"{table}.csv"
    if not path.exists():
        raise FileNotFoundError(f"{path} is missing. Run src/generate_data.py first.")
    frame = pd.read_csv(path)
    for column in DATE_COLUMNS.get(table, []):
        frame[column] = pd.to_datetime(frame[column], utc=True)
    if table == "orders":
        frame["delivery_days"] = pd.to_numeric(frame["delivery_days"], errors="coerce").astype("Int64")
    frame = frame.where(pd.notna(frame), None)
    return frame


def validate(tables: dict[str, pd.DataFrame]) -> None:
    assert tables["customers"]["customer_id"].is_unique
    assert tables["orders"]["order_id"].is_unique
    assert tables["order_items"]["order_item_id"].is_unique
    assert set(tables["orders"]["customer_id"]).issubset(set(tables["customers"]["customer_id"]))
    assert set(tables["order_items"]["order_id"]).issubset(set(tables["orders"]["order_id"]))
    assert (tables["order_items"]["quantity"] > 0).all()


def main() -> None:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise EnvironmentError("Set DATABASE_URL before loading, for example postgresql+psycopg://portfolio:portfolio@localhost:5434/ecommerce")

    tables = {name: read_table(name) for name in TABLES}
    validate(tables)
    engine = create_engine(database_url)
    with engine.begin() as connection:
        connection.execute(text("TRUNCATE TABLE returns, payments, order_items, orders, products, customers CASCADE"))
        for name in TABLES:
            # PostgreSQL limits a single statement to 65,535 bind parameters.
            # Batching also keeps the loader stable for larger CSV files.
            tables[name].to_sql(name, connection, if_exists="append", index=False, method="multi", chunksize=500)
            print(f"Loaded {len(tables[name]):,} rows into {name}")


if __name__ == "__main__":
    main()
