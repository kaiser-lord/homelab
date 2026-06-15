#!/bin/bash
# media-to-onedrive.sh - Weekly incremental backup to OneDrive Personal

SOURCE="/mnt/media"
REMOTE="media_backup_prod:NAS_Media_Backups"
BACKUP_DIR="media_backup_prod:_NAS_Media_archive_data/$(date +%Y-%m-%d_%H%M%S)"
LOG="/var/log/media-to-cloud.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Rotate log if bigger than 100MB
if [ $(stat -c%s "$LOG" 2>/dev/null || echo 0) -gt 104857600 ]; then
    mv "$LOG" "$LOG.$(date +%Y%m%d-%H%M%S).old"
fi

echo "==================================================" | tee -a $LOG
echo "Media backup started - $DATE" | tee -a $LOG
echo "Source: $SOURCE" | tee -a $LOG
echo "Destination: $REMOTE" | tee -a $LOG
echo "Deleted files archive: $BACKUP_DIR" | tee -a $LOG
echo "==================================================" | tee -a $LOG

rclone sync "$SOURCE" "$REMOTE" \
    --log-file="$LOG" \
    --log-level INFO \
    --stats-one-line \
    --stats 60s \
    --transfers 12 \
    --checkers 20 \
    --tpslimit 8 \
    --tpslimit-burst 15 \
    --onedrive-delta \
    --fast-list \
    --retries 5 \
    --retries-sleep 30s \
    --low-level-retries 10 \
    --timeout 5m \
    --progress \
    --exclude ".snapshot/**" \
    --exclude "**Thumbs.db" \
    --exclude "**~*" \
    --backup-dir "$BACKUP_DIR" \
    --delete-excluded

EXIT_CODE=$?

echo "==================================================" | tee -a $LOG
if [ $EXIT_CODE -eq 0 ]; then
    echo "SUCCESS - Backup completed successfully - $(date '+%Y-%m-%d %H:%M:%S')" | tee -a $LOG
else
    echo "FAILED - Backup finished with errors (exit code $EXIT_CODE) - $(date '+%Y-%m-%d %H:%M:%S')" | tee -a $LOG
fi
echo "==================================================" | tee -a $LOG

exit $EXIT_CODE
