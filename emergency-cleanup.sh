#!/bin/bash

# EMERGENCY: Remove exposed secrets from Git history
# Run this script to clean up the exposed secrets

echo "🚨 EMERGENCY SECRET CLEANUP"
echo "=========================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if we're in a git repo
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  WARNING: This will rewrite git history!${NC}"
echo "Make sure you have a backup before proceeding."
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Creating backup..."
cd ..
BACKUP_DIR="pocket-organizer-backup-$(date +%Y%m%d-%H%M%S)"
cp -r pocket-organizer "$BACKUP_DIR"
echo -e "${GREEN}✅ Backup created: $BACKUP_DIR${NC}"
cd pocket-organizer

echo ""
echo "Step 2: Removing sensitive files from git history..."

# Remove GoogleService-Info.plist
echo "Removing GoogleService-Info.plist..."
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch ios/Runner/GoogleService-Info.plist" \
  --prune-empty --tag-name-filter cat -- --all

# Remove ENV_SETUP.md
echo "Removing ENV_SETUP.md..."
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch ENV_SETUP.md" \
  --prune-empty --tag-name-filter cat -- --all

# Remove .env.example
echo "Removing .env.example..."
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env.example" \
  --prune-empty --tag-name-filter cat -- --all

echo -e "${GREEN}✅ Files removed from history${NC}"

echo ""
echo "Step 3: Cleaning up..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo -e "${GREEN}✅ Cleanup complete${NC}"

echo ""
echo "Step 4: Updating .gitignore..."
git add .gitignore
git commit -m "chore: Update gitignore to prevent future secret leaks"

echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Next steps:${NC}"
echo ""
echo "1. Force push to GitHub:"
echo "   git push --force origin main"
echo ""
echo "2. Regenerate ALL exposed credentials:"
echo "   - Firebase API keys (create new project)"
echo "   - MongoDB password (change in Atlas)"
echo "   - Google API keys (regenerate)"
echo ""
echo "3. Update local .env file with new credentials"
echo ""
echo "4. Run flutter app with new credentials"
echo ""
echo -e "${RED}DO NOT skip step 2! Exposed credentials are still valid!${NC}"

