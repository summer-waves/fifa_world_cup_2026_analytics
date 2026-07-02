#!/bin/bash
set -e

echo "=== 1/3: Loading staging tables ==="
python scripts/load_staging.py

echo ""
echo "=== 2/3: Running dimensional transform ==="
docker exec -i fifa_wc_postgres psql -U marco -d fifa_worldcup < sql/02_transform.sql

echo ""
echo "=== 3/3: Training model + writing predictions ==="
python scripts/train_predict.py

echo ""
echo "Pipeline complete."