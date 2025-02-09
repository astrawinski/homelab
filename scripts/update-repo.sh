#!/bin/bash

# Navigate to the homelab directory
cd "$(dirname "$0")/../" || exit 1

echo "Fetching latest updates from GitHub..."

# Check if there are local changes
if [[ -n $(git status --porcelain) ]]; then
    echo "⚠️ Local changes detected!"

    # Auto-commit changes if there are modified files (excluding untracked files)
    if [[ -n $(git status --porcelain | grep '^ M') ]]; then
        echo "📌 Auto-committing local changes..."
        git add .
        git commit -m "Auto-commit: Saving local changes before pulling updates"
    fi

    # Stash untracked changes if any exist
    if [[ -n $(git status --porcelain | grep '^??') ]]; then
        echo "🔄 Stashing untracked files..."
        git stash push -m "Auto-stash before pull"
    fi
fi

# Pull the latest updates from GitHub
git pull origin main --rebase

# Apply stashed changes if any were stashed
if git stash list | grep -q "Auto-stash before pull"; then
    echo "🔄 Applying stashed changes back..."
    git stash pop
fi

echo "✅ Repository is up to date!"
