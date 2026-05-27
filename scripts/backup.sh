#!/usr/bin/env bash
set -euo pipefail

BASE=~/erpnext
COMPOSE_DIR=$BASE/frappe_docker
TS=$(date +%F_%H-%M-%S)
BKDIR=$BASE/backups/$TS
RETENTION_DAYS=7

mkdir -p $BKDIR

cd $COMPOSE_DIR

# Step 1: Database + files backup via bench
echo "[backup] Running bench backup..."
docker compose exec -T backend bash -c "bench --site erpnext.example.com backup --with-files" 2>&1 || echo "[backup] WARNING: bench backup had issues"

# Step 2: Copy backup files from site
SITE_DIR=$(docker compose exec -T backend bash -c "find sites/erpnext.example.com/private/backups -type f -name '*.sql.gz' -o -name '*.tgz' -o -name '*.tar.gz'" 2>/dev/null | tail -5)
if [ -n "$SITE_DIR" ]; then
  docker compose cp backend:"/home/frappe/frappe-bench/sites/erpnext.example.com/private/backups" $BKDIR/ 2>/dev/null || true
fi

# Step 3: Archive sites directory (config only, no files already backed up)
echo "[backup] Archiving sites config..."
docker compose exec -T backend bash -c "tar -czf /tmp/sites-config.tar.gz -C sites erpnext.example.com/site_config.json erpnext.example.com/letters erpnext.example.com/letter_heads" 2>/dev/null || true
docker compose cp backend:/tmp/sites-config.tar.gz $BKDIR/ 2>/dev/null || true

# Step 4: Backup compose config files
cp $COMPOSE_DIR/compose.yaml $BKDIR/
cp $COMPOSE_DIR/.env $BKDIR/
cp $COMPOSE_DIR/overrides/compose.lxc.yaml $BKDIR/
cp $BASE/mariadb-conf/tuning.cnf $BKDIR/

echo "[backup] Backup complete: $BKDIR"

# Step 5: Clean old backups
find $BASE/backups -maxdepth 2 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true

# Step 6: Print size
du -sh $BKDIR
