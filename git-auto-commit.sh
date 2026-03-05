#!/bin/bash

# Auto-commit and push to git after changes
# Usage: git-auto-commit.sh [message]

REPO_DIR="/srv/server"
MESSAGE="${1:-Auto-update: $(date '+%Y-%m-%d %H:%M:%S')}"

cd "$REPO_DIR" || exit 1

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "Error: Not a git repository"
    exit 1
fi

# Stage all changes
git add -A

# Check if there are changes to commit
if ! git diff-index --quiet HEAD --; then
    echo "📝 Committing changes: $MESSAGE"
    git commit -m "$MESSAGE"
    
    # Push to remote
    if git remote -v | grep -q origin; then
        echo "🚀 Pushing to remote..."
        git push origin main 2>/dev/null || git push origin master 2>/dev/null || {
            echo "⚠️ Push failed (no remote or no main/master branch)"
            exit 1
        }
        echo "✅ Pushed successfully"
    else
        echo "ℹ️ No remote configured (local commit only)"
    fi
else
    echo "✔️ No changes to commit"
fi
