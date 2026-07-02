import os
import pandas as pd
from sqlalchemy import create_engine
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

RAW_DIR = Path("data/raw")
DB_URI = f"postgresql+psycopg2://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@localhost:5432/{os.getenv('POSTGRES_DB')}"

FILES = [
    "players.csv",
    "teams.csv",
    "test.csv",
    "wc_2026_fixtures.csv",
    "wc_2026_teams.csv",
    "wc_all_editions.csv",
    "train.csv",
    "wc_all_matches.csv",
    "wc_top_scorers.csv",
]

def to_table_name(filename: str) -> str:
    return "stg_" + filename.replace(".csv", "")

def main():
    engine = create_engine(DB_URI)
    for fname in FILES:
        path = RAW_DIR / fname
        if not path.exists():
            print(f"MISSING: {path}")
            continue
        try:
            df = pd.read_csv(path, encoding="utf-8")
        except UnicodeDecodeError:
            df = pd.read_csv(path, encoding="latin1")
        table = to_table_name(fname)
        df.to_sql(table, engine, schema="staging", if_exists="replace", index=False)
        print(f"Loaded {fname} -> staging.{table}  ({len(df)} rows, {len(df.columns)} cols)")

if __name__ == "__main__":
    main()
