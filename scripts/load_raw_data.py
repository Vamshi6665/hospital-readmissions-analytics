"""
Hospital Readmissions Analytics - Raw Data Ingestion

Loads the Diabetes 130-US Hospitals dataset from CSV into Postgres raw schema.
Source: https://www.kaggle.com/datasets/brandao/diabetes (UCI ML Repository)
"""

import os
import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text


# ============ CONFIGURATION ============

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data" / "raw"
DIABETIC_DATA_FILE = DATA_DIR / "diabetic_data.csv"
IDS_MAPPING_FILE = DATA_DIR / "IDS_mapping.csv"

DB_USER = "postgres"
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "REPLACE_ME")
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "readmissions"
DB_SCHEMA = "raw"

CONN_STRING = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"


def load_diabetic_data(engine):
    print(f"\n-> Loading {DIABETIC_DATA_FILE.name}...")
    if not DIABETIC_DATA_FILE.exists():
        sys.exit(f"ERROR: File not found: {DIABETIC_DATA_FILE}")

    df = pd.read_csv(DIABETIC_DATA_FILE, na_values="?")
    print(f"  Rows: {len(df):,}")
    print(f"  Columns: {len(df.columns)}")
    print(f"  Missing-value cells: {df.isna().sum().sum():,}")

    df.to_sql(
        "diabetic_data",
        engine,
        schema=DB_SCHEMA,
        if_exists="replace",
        index=False,
        chunksize=10000,
        method="multi",
    )
    print(f"  SUCCESS: Loaded into {DB_SCHEMA}.diabetic_data")


def load_ids_mapping(engine):
    print(f"\n-> Loading {IDS_MAPPING_FILE.name}...")
    if not IDS_MAPPING_FILE.exists():
        print(f"  SKIPPED: {IDS_MAPPING_FILE.name} not found (mappings will be hardcoded in dbt)")
        return

    with open(IDS_MAPPING_FILE, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]

    section_headers = [
        "admission_type_id,description",
        "discharge_disposition_id,description",
        "admission_source_id,description",
    ]
    section_names = ["admission_type", "discharge_disposition", "admission_source"]

    sections = {}
    current_section = None
    for line in lines:
        if line in section_headers:
            idx = section_headers.index(line)
            current_section = section_names[idx]
            sections[current_section] = []
        elif current_section:
            sections[current_section].append(line)

    for name, rows in sections.items():
        if not rows:
            continue
        df = pd.DataFrame(
            [r.split(",", 1) for r in rows],
            columns=[f"{name}_id", "description"],
        )
        df[f"{name}_id"] = pd.to_numeric(df[f"{name}_id"], errors="coerce")
        df.to_sql(f"ids_{name}", engine, schema=DB_SCHEMA, if_exists="replace", index=False)
        print(f"  SUCCESS: Loaded {len(df)} rows into {DB_SCHEMA}.ids_{name}")


def verify_loads(engine):
    print("\n=== Verification ===")
    tables = ["diabetic_data"]
    with engine.connect() as conn:
        for name in ["ids_admission_type", "ids_discharge_disposition", "ids_admission_source"]:
            result = conn.execute(text(
                f"SELECT to_regclass('{DB_SCHEMA}.{name}') IS NOT NULL"
            )).scalar()
            if result:
                tables.append(name)

        for t in tables:
            count = conn.execute(text(f"SELECT COUNT(*) FROM {DB_SCHEMA}.{t}")).scalar()
            print(f"  {DB_SCHEMA}.{t:30s}  {count:>8,} rows")


def main():
    print("=" * 60)
    print("  Hospital Readmissions - Raw Data Ingestion")
    print("=" * 60)

    if DB_PASSWORD == "REPLACE_ME":
        sys.exit(
            "\nERROR: Set your Postgres password first:\n"
            "   $env:POSTGRES_PASSWORD = 'your_password_here'"
        )

    engine = create_engine(CONN_STRING)
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("\nSUCCESS: Postgres connection OK")
    except Exception as e:
        sys.exit(f"\nERROR: Could not connect to Postgres: {e}")

    load_diabetic_data(engine)
    load_ids_mapping(engine)
    verify_loads(engine)

    print("\nSUCCESS: All raw data loaded.")


if __name__ == "__main__":
    main()