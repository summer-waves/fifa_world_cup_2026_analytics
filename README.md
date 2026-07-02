# FIFA World Cup 2026 — Championship Prediction Analytics

An end-to-end analytics project combining **PostgreSQL**, **Python (XGBoost)**, and **Power BI** to predict FIFA World Cup 2026 championship outcomes from historical tournament data and live 2026 team/player statistics.

## Overview

This project builds a full data pipeline — from raw, messy CSV sources through a normalized data warehouse, a trained machine learning model, and an interactive multi-page BI dashboard — to answer one question: **who is most likely to win the 2026 World Cup, based on historical patterns and current tournament form?**

## Tech Stack

| Layer | Tools |
|---|---|
| Data Storage | PostgreSQL 16 (Dockerized) |
| Data Engineering | Python (pandas, SQLAlchemy), raw SQL |
| Machine Learning | XGBoost, scikit-learn |
| Visualization | Power BI Desktop |
| Orchestration | Bash (single-command pipeline) |

## Architecture

```
Kaggle CSVs (9 raw sources)
        │
        ▼
Python ingestion (load_staging.py)
        │  encoding-safe CSV loading
        ▼
Postgres staging schema (9 raw tables)
        │
        ▼
SQL transform (02_transform.sql)
        │  country-name normalization
        │  star schema construction
        ▼
Postgres dimensional model
  ├─ dim_country
  ├─ dim_player
  ├─ dim_tournament_edition
  ├─ fact_matches
  ├─ fact_player_stats
  └─ fact_team_stats
        │
        ▼
Python ML pipeline (train_predict.py)
  │  XGBoost classifiers (4 binary targets)
  │  cross-validated on historical tournaments
  ▼
predictions table (Postgres)
        │
        ▼
Power BI (3-page interactive dashboard)
  ├─ Prediction Dashboard
  ├─ Team Deep-Dive
  └─ Player Leaderboard
```

## Data Sources

Nine Kaggle datasets combined into a single warehouse:

- Historical World Cup team performance (1930–2022), with FIFA rankings, squad market value, and outcome labels
- 2026 team lineup and FIFA rankings (48 teams)
- 2026 player statistics, updated per matchday
- 2026 fixture list
- Full historical match results (1930–2022)
- Historical Golden Boot / top scorer records
- Baseline train/test feature sets for the 2026 field

## Data Engineering Highlights

Real-world data quality issues encountered and resolved:

- **Country name normalization** — merged 9 sets of inconsistent naming across sources (e.g. `USA` / `United States`, `Korea Republic` / `South Korea`, `Côte d'Ivoire` / `Ivory Coast`, `Czechia` / `Czech Republic`) via a dedicated `country_name_map` staging table
- **Character encoding repair** — a corrupted byte sequence in the source CSV rendered "Curaçao" as `Cura?o`; fixed with a targeted `LIKE`-pattern `UPDATE` at the transform layer
- **Type casting** — resolved a `date`-as-text column mismatch during fact table construction
- **Staging-first architecture** — raw CSVs are loaded unmodified into a `staging` schema before any transformation, so the pipeline is auditable and re-runnable end-to-end

## Machine Learning

Four independent XGBoost binary classifiers predict, for each of the 48 competing nations, the probability of reaching:

- Champion
- Finalist
- Semifinalist
- Quarterfinalist

**Cross-validated performance (5-fold, ROC-AUC):**

| Target | AUC |
|---|---|
| Champion | 0.785 |
| Finalist | 0.694 |
| Semifinalist | 0.740 |
| Quarterfinalist | 0.715 |

> **Note on model limitations:** the training set contains 192 historical team-tournament observations. AUC scores at this sample size carry meaningful variance across runs and should be read as directional signal, not precise probability estimates.

## Dashboard Pages

1. **Prediction Dashboard** — championship probability rankings, predicted champion callout, top-10 contenders visualized
2. **Team Deep-Dive** — interactive country selector driving goals/possession/squad-age comparisons and a live possession gauge
3. **Player Leaderboard** — top scorers and assist leaders across the 2026 tournament

## Project Structure

```
fifa-world-cup-2026/
├── data/raw/                  # Source CSVs
├── scripts/
│   ├── load_staging.py        # CSV → Postgres staging
│   └── train_predict.py       # Model training + prediction write-back
├── sql/
│   ├── 01_schema.sql          # Dimensional model DDL
│   ├── create_name_map.sql    # Country name normalization table
│   └── 02_transform.sql       # Staging → dimensional model transform
├── docker-compose.yml         # Postgres container definition
├── run_pipeline.sh            # One-command full pipeline execution
└── README.md
```

## Running the Pipeline

```bash
# Start the database
docker compose up -d

# Run the full pipeline (staging load → transform → model → predictions)
./run_pipeline.sh
```

## Future Improvements

- Live re-training as group-stage results come in, with Evidently-based drift monitoring on model inputs
- Expand feature set with player-level aggregates (squad injury/availability signals)
- CI/CD via GitHub Actions for automated pipeline runs on data refresh