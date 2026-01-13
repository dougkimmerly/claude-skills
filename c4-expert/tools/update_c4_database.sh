#!/bin/bash
# Update C4 Database from Latest NAS Backup
#
# This script downloads the latest Control4 backup from the NAS,
# extracts it, and rebuilds the SQLite database.
#
# NAS Location: doug@192.168.20.16:/volume1/Home Files/Data/Documents/House Documents/Control4/Projects

set -e

TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
NAS_HOST="doug@192.168.20.16"
NAS_PATH="/volume1/Home Files/Data/Documents/House Documents/Control4/Projects"
TEMP_DIR="/tmp/c4_extract_$(date +%s)"

echo "Creating temporary directory: $TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "Finding latest backup on NAS..."
LATEST_BACKUP=$(ssh "$NAS_HOST" "ls -t '$NAS_PATH'/*.c4p | head -1")
BACKUP_NAME=$(basename "$LATEST_BACKUP")

echo "Latest backup: $BACKUP_NAME"
echo "Downloading from NAS..."
ssh "$NAS_HOST" "cat '$LATEST_BACKUP'" > "$BACKUP_NAME"

echo "Extracting project.xml..."
unzip -q "$BACKUP_NAME"

if [ ! -f "project.xml" ]; then
    echo "Error: project.xml not found in backup!"
    exit 1
fi

echo "Parsing XML to SQLite database..."
python3 "$TOOLS_DIR/c4_xml_to_db.py" project.xml "$TOOLS_DIR/c4_project_new.db"

echo "Backing up old database..."
if [ -f "$TOOLS_DIR/c4_project.db" ]; then
    mv "$TOOLS_DIR/c4_project.db" "$TOOLS_DIR/c4_project_old.db"
fi

echo "Installing new database..."
mv "$TOOLS_DIR/c4_project_new.db" "$TOOLS_DIR/c4_project.db"

echo "Cleaning up..."
cd "$TOOLS_DIR"
rm -rf "$TEMP_DIR"

echo ""
echo "Database updated successfully!"
echo "You can now query with: ./c4query --stats"
