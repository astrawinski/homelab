#!/bin/bash

# Navigate to the homelab directory (adjust this path if needed)
cd "$(dirname "$0")/../" || exit

# Ensure the logs directory exists
mkdir -p logs

# Define the log file
LOG_FILE="logs/docs-sync.log"

# Check for changes in the docs/ directory
CHANGED_FILES=$(git diff --name-status docs/)

# If no changes, exit
if [ -z "$CHANGED_FILES" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - No changes detected in docs/. Exiting." | tee -a "$LOG_FILE"
    exit 0
fi

# Show detected changes
echo "Detected changes in homelab documentation:"
echo "$CHANGED_FILES"

# Log the changes
echo "$(date +"%Y-%m-%d %H:%M:%S") - Detected changes:" >> "$LOG_FILE"
echo "$CHANGED_FILES" >> "$LOG_FILE"
echo "---------------------------------" >> "$LOG_FILE"

# Show a preview of what changed
echo -e "\n--- Git Diff Preview ---\n"
git diff -- docs/

# Ask for confirmation before committing
read -p "Commit and push these changes? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Commit aborted by user." | tee -a "$LOG_FILE"
    echo "Aborting commit."
    exit 0
fi

# Commit and push the changes
git add docs/
git commit -m "Updated homelab documentation"
git push origin main

# Log successful commit
echo "$(date +"%Y-%m-%d %H:%M:%S") - Changes successfully committed and pushed." | tee -a "$LOG_FILE"
echo "Changes successfully committed and pushed!"
exit 0
