#!/bin/bash

# Navigate to the homelab directory (adjust this path if needed)
cd "$(dirname "$0")/../" || exit

# Ensure the logs directory exists
mkdir -p logs

# Define the log file
LOG_FILE="logs/repo-sync.log"
COPY_TO_CLIPBOARD=false

# Check for command-line arguments
if [[ "$1" == "--copy" ]]; then
    COPY_TO_CLIPBOARD=true
fi

# Check for all changes in the repository
CHANGED_FILES=$(git status --porcelain)

# If no changes, exit
if [ -z "$CHANGED_FILES" ]; then
    OUTPUT="$(date +"%Y-%m-%d %H:%M:%S") - No changes detected in repo. Exiting."
    echo "$OUTPUT" | tee -a "$LOG_FILE"
    if [[ "$COPY_TO_CLIPBOARD" == true ]]; then
        echo "$OUTPUT" | copy_to_clipboard
    fi
    exit 0
fi

# Show detected changes
echo "Detected changes in homelab repository:"
echo "$CHANGED_FILES"

# Log the changes
echo "$(date +"%Y-%m-%d %H:%M:%S") - Detected changes:" >> "$LOG_FILE"
echo "$CHANGED_FILES" >> "$LOG_FILE"
echo "---------------------------------" >> "$LOG_FILE"

# Show a preview of what changed
echo -e "\n--- Git Diff Preview ---\n"
GIT_DIFF_OUTPUT=$(git diff)
echo "$GIT_DIFF_OUTPUT"

# Ask for confirmation before committing
read -p "Commit and push these changes? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    OUTPUT="$(date +"%Y-%m-%d %H:%M:%S") - Commit aborted by user."
    echo "$OUTPUT" | tee -a "$LOG_FILE"
    if [[ "$COPY_TO_CLIPBOARD" == true ]]; then
        echo "$OUTPUT" | copy_to_clipboard
    fi
    echo "Aborting commit."
    exit 0
fi

# Add all changes except .bak and temp files
git add --all -- ':!*.bak' ':!temp/' ':!*.swp' ':!*.tmp'
git rm --cached $(git ls-files --deleted) 2>/dev/null

# Create a commit message with a timestamp
COMMIT_MESSAGE="Updated homelab repository - $(date +"%Y-%m-%d %H:%M:%S")"
git commit -m "$COMMIT_MESSAGE"

# Push the changes
git push origin main

# Log successful commit
OUTPUT="$(date +"%Y-%m-%d %H:%M:%S") - Changes successfully committed and pushed. Commit message: $COMMIT_MESSAGE"
echo "$OUTPUT" | tee -a "$LOG_FILE"

# Copy output to clipboard if enabled
if [[ "$COPY_TO_CLIPBOARD" == true ]]; then
    echo "$OUTPUT" | copy_to_clipboard
fi

echo "Changes successfully committed and pushed!"
exit 0

# Function to copy output to clipboard
copy_to_clipboard() {
    if command -v xclip &> /dev/null; then
        xclip -selection clipboard
    elif command -v pbcopy &> /dev/null; then
        pbcopy
    else
        echo "Clipboard copy failed: No clipboard utility found (install xclip or pbcopy)." >&2
    fi
}
