"""
Train XGBoost classifiers on historical World Cup outcomes (stg_train)
and predict champion/finalist/semifinalist/quarterfinalist probabilities
for the 2026 field (stg_test). Writes results into the predictions table.
"""
import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text
from xgboost import XGBClassifier
from sklearn.model_selection import cross_val_score

DB_URI = f"postgresql+psycopg2://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@localhost:5432/{os.getenv('POSTGRES_DB')}"
MODEL_VERSION = "xgboost_v1"

TARGET_COLS = ["winner", "finalist", "semi_finalist", "quarter_finalist"]
DROP_COLS = TARGET_COLS + ["version", "team"]

engine = create_engine(DB_URI)

# --- Load data ---
train = pd.read_sql("SELECT * FROM staging.stg_train", engine)
test = pd.read_sql("SELECT * FROM staging.stg_test", engine)

# --- Encode continent, align columns between train/test ---
train_enc = pd.get_dummies(train, columns=["continent"], prefix="cont")
test_enc = pd.get_dummies(test, columns=["continent"], prefix="cont")
train_enc, test_enc = train_enc.align(test_enc, join="outer", axis=1, fill_value=0)

feature_cols = [c for c in train_enc.columns if c not in DROP_COLS]

X_train = train_enc[feature_cols].apply(pd.to_numeric, errors="coerce")
X_test = test_enc[feature_cols].apply(pd.to_numeric, errors="coerce")

# --- Train one binary classifier per stage, report cross-val AUC ---
results = test[["team"]].copy()

for target in TARGET_COLS:
    y = train_enc[target].fillna(0).astype(int)

    model = XGBClassifier(
        n_estimators=200,
        max_depth=3,
        learning_rate=0.05,
        eval_metric="logloss",
        random_state=42,
    )

    # Quick cross-val sanity check before fitting on full data
    try:
        auc_scores = cross_val_score(model, X_train, y, cv=5, scoring="roc_auc")
        print(f"{target}: mean CV AUC = {auc_scores.mean():.3f}")
    except ValueError as e:
        print(f"{target}: CV skipped ({e})")

    model.fit(X_train, y)
    results[target] = model.predict_proba(X_test)[:, 1]

# --- Normalize winner probability so it reflects relative championship odds ---
results["winner_normalized"] = results["winner"] / results["winner"].sum()

print("\nTop 10 championship contenders:")
print(results.sort_values("winner_normalized", ascending=False)[["team", "winner_normalized"]].head(10))

# --- Map team -> country_id using the same canonicalization as the SQL layer ---
name_map = pd.read_sql("SELECT raw_name, canonical_name FROM staging.country_name_map", engine)
name_map_dict = dict(zip(name_map.raw_name, name_map.canonical_name))

dim_country = pd.read_sql("SELECT country_id, country_name FROM dim_country", engine)

results["canonical_name"] = results["team"].map(lambda t: name_map_dict.get(t, t))
results = results.merge(dim_country, left_on="canonical_name", right_on="country_name", how="left")

missing = results[results["country_id"].isna()]
if not missing.empty:
    print("\nWARNING: unmatched teams (won't be written to predictions):")
    print(missing[["team"]])

edition_id = pd.read_sql(
    "SELECT edition_id FROM dim_tournament_edition WHERE year = 2026", engine
).iloc[0]["edition_id"]

# --- Reshape wide -> long: one row per (country, predicted_stage) ---
long_rows = []
for _, row in results.dropna(subset=["country_id"]).iterrows():
    for stage, col in [
        ("champion", "winner"),
        ("finalist", "finalist"),
        ("semifinalist", "semi_finalist"),
        ("quarterfinalist", "quarter_finalist"),
    ]:
        long_rows.append({
            "country_id": int(row["country_id"]),
            "edition_id": int(edition_id),
            "predicted_stage": stage,
            "win_probability": round(float(row[col]), 4),
            "model_version": MODEL_VERSION,
        })

predictions_df = pd.DataFrame(long_rows)

# --- Write to Postgres (replace this run's predictions, keep table structure) ---
with engine.begin() as conn:
    conn.execute(text(
        "DELETE FROM predictions WHERE model_version = :v AND edition_id = :e"
    ), {"v": MODEL_VERSION, "e": int(edition_id)})

predictions_df.to_sql("predictions", engine, if_exists="append", index=False)

print(f"\nWrote {len(predictions_df)} prediction rows to Postgres.")