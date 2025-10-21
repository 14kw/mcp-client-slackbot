#!/bin/bash
set -e

# Configuration
DB_PATH="${DB_PATH:-/data/test.db}"
GCS_BUCKET="${GCS_BUCKET:-}"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}"  # 5 minutes default

echo "Starting MCP Slackbot..."
echo "Database path: ${DB_PATH}"
echo "GCS bucket: ${GCS_BUCKET:-not configured}"
echo "Sync interval: ${SYNC_INTERVAL} seconds"

# Function to sync database to GCS
sync_to_gcs() {
    if [ -n "${GCS_BUCKET}" ] && [ -f "${DB_PATH}" ]; then
        echo "Syncing database to GCS..."
        python3 -c "
from db_sync import sync_database_to_gcs
import sys
success = sync_database_to_gcs('${GCS_BUCKET}', '${DB_PATH}')
sys.exit(0 if success else 1)
" || echo "Warning: Failed to sync database to GCS"
    fi
}

# Function to handle shutdown
shutdown_handler() {
    echo "Received shutdown signal, syncing database..."
    sync_to_gcs
    echo "Shutdown complete"
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Initialize database directory and sync from GCS
python3 -c "
from db_sync import ensure_database_dir, sync_database_from_gcs
import sys
import logging

logging.basicConfig(level=logging.INFO)

if not ensure_database_dir('${DB_PATH}'):
    sys.exit(1)

if not sync_database_from_gcs('${GCS_BUCKET}', '${DB_PATH}'):
    sys.exit(1)
" || exit 1

# Start periodic sync in background if GCS is configured
if [ -n "${GCS_BUCKET}" ]; then
    (
        while true; do
            sleep ${SYNC_INTERVAL}
            sync_to_gcs
        done
    ) &
    SYNC_PID=$!
fi

# Start the main application
python3 main.py &
APP_PID=$!

# Wait for the application to exit
wait $APP_PID
APP_EXIT_CODE=$?

# Clean up background sync process
if [ -n "${SYNC_PID}" ]; then
    kill $SYNC_PID 2>/dev/null || true
fi

# Final sync before exit
sync_to_gcs

exit $APP_EXIT_CODE
