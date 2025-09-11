#!/bin/bash
set -euo pipefail

# --- Configuration ---
# Source environment variables from the .env file
export $(grep -v '^#' /opt/pg-cluster/.env | xargs)

BACKUP_DIR="/opt/pg-cluster/backups/daily"
RETENTION_DAYS=7
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="${BACKUP_DIR}/backup-${POSTGRES_DB}-${DATE}.sql.gz.custom"
LOG_FILE="/opt/pg-cluster/logs/backup.log"

# --- Main Logic ---
echo "--- Starting backup for ${POSTGRES_DB} at $(date) ---" >> "${LOG_FILE}"

# Perform the database dump using the running 'db' container
docker exec -i postgres_db pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" --format=custom | gzip > "${FILENAME}"

# Check if the backup file was created and is not empty
if [ -s "${FILENAME}" ]; then
    echo "Successfully created backup: ${FILENAME}" >> "${LOG_FILE}"
else
    echo "ERROR: Backup failed or created an empty file." >> "${LOG_FILE}"
    exit 1
fi

# Prune old backups
echo "Pruning backups older than ${RETENTION_DAYS} days..." >> "${LOG_FILE}"
find "${BACKUP_DIR}" -type f -mtime +${RETENTION_DAYS} -name '*.sql.gz.custom' -print -delete >> "${LOG_FILE}"

echo "--- Backup complete at $(date) ---" >> "${LOG_FILE}"
echo "" >> "${LOG_FILE}"
