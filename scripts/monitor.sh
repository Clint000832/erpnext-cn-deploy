#!/usr/bin/env bash
set -euo pipefail

echo "=== Container Status ==="
docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null

echo "" 
echo "=== Disk Usage ==="
df -h / 2>/dev/null | tail -1

echo ""
echo "=== Memory ==="
free -h 2>/dev/null | grep -E '(Mem|Swap)'

echo ""
echo "=== Backup Space ==="
du -sh ~/erpnext/backups 2>/dev/null || echo "(no backups yet)"

echo ""
echo "=== Last Backup ==="
ls -lt ~/erpnext/backups/ 2>/dev/null | head -3 || echo "(no backups yet)"
