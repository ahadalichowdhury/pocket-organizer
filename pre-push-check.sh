#!/bin/bash

# Pre-Push Security Check Script
# Run this before pushing to GitHub to ensure no sensitive data is committed

echo "🔍 Running pre-push security check..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Check 1: Service account files
echo "1️⃣  Checking for Firebase service account files..."
SERVICE_ACCOUNTS=$(find . -name "*service-account*.json" -o -name "*adminsdk*.json" 2>/dev/null | grep -v node_modules | grep -v ".git")
if [ -n "$SERVICE_ACCOUNTS" ]; then
    echo -e "${RED}❌ DANGER: Found service account files:${NC}"
    echo "$SERVICE_ACCOUNTS"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ No service account files found${NC}"
fi
echo ""

# Check 2: .env files
echo "2️⃣  Checking for .env files..."
ENV_FILES=$(find . -name ".env*" 2>/dev/null | grep -v node_modules | grep -v ".git")
if [ -n "$ENV_FILES" ]; then
    echo -e "${YELLOW}⚠️  Found .env files (check if they're in .gitignore):${NC}"
    echo "$ENV_FILES"
    # Check if they're actually being tracked
    for file in $ENV_FILES; do
        if git ls-files --error-unmatch "$file" > /dev/null 2>&1; then
            echo -e "${RED}❌ DANGER: $file is being tracked by git!${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    echo -e "${GREEN}✅ No .env files found or all properly ignored${NC}"
fi
echo ""

# Check 3: Hardcoded API keys in code
echo "3️⃣  Checking for hardcoded API keys in Dart files..."
if grep -r "sk-proj" lib/ --include="*.dart" > /dev/null 2>&1; then
    echo -e "${RED}❌ DANGER: Found OpenAI API key in code!${NC}"
    grep -rn "sk-proj" lib/ --include="*.dart"
    ERRORS=$((ERRORS + 1))
elif grep -r "AAAA" lib/ --include="*.dart" | grep -v "example" > /dev/null 2>&1; then
    echo -e "${RED}❌ DANGER: Found Firebase server key in code!${NC}"
    grep -rn "AAAA" lib/ --include="*.dart" | grep -v "example"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ No hardcoded API keys found in Dart files${NC}"
fi
echo ""

# Check 4: MongoDB connection strings
echo "4️⃣  Checking for MongoDB connection strings..."
if grep -r "mongodb+srv://" lib/ --include="*.dart" | grep -v "example" | grep -v "your_connection_string" > /dev/null 2>&1; then
    echo -e "${RED}❌ DANGER: Found MongoDB connection string in code!${NC}"
    grep -rn "mongodb+srv://" lib/ --include="*.dart" | grep -v "example" | grep -v "your_connection_string"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ No MongoDB connection strings found${NC}"
fi
echo ""

# Check 5: Staged files
echo "5️⃣  Checking staged files..."
STAGED_FILES=$(git diff --cached --name-only)
if [ -z "$STAGED_FILES" ]; then
    echo -e "${YELLOW}⚠️  No files staged for commit${NC}"
else
    echo -e "${GREEN}✅ Files staged for commit:${NC}"
    echo "$STAGED_FILES" | head -10
    FILE_COUNT=$(echo "$STAGED_FILES" | wc -l | tr -d ' ')
    if [ $FILE_COUNT -gt 10 ]; then
        echo "... and $((FILE_COUNT - 10)) more files"
    fi
fi
echo ""

# Check 6: .gitignore exists
echo "6️⃣  Checking .gitignore..."
if [ -f ".gitignore" ]; then
    echo -e "${GREEN}✅ .gitignore exists${NC}"
    if grep -q "firebase-adminsdk" .gitignore && grep -q ".env" .gitignore; then
        echo -e "${GREEN}✅ .gitignore has sensitive file patterns${NC}"
    else
        echo -e "${YELLOW}⚠️  .gitignore might be missing some patterns${NC}"
    fi
else
    echo -e "${RED}❌ DANGER: .gitignore does not exist!${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Final verdict
echo "================================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ ✅ ✅  ALL CHECKS PASSED! Safe to push! ✅ ✅ ✅${NC}"
    echo ""
    echo "Next steps:"
    echo "  git add ."
    echo "  git commit -m \"Your commit message\""
    echo "  git push"
else
    echo -e "${RED}❌ ❌ ❌  $ERRORS SECURITY ISSUE(S) FOUND! ❌ ❌ ❌${NC}"
    echo ""
    echo "DO NOT PUSH until you fix the issues above!"
    echo ""
    echo "To fix:"
    echo "  1. Move sensitive files outside the project"
    echo "  2. Add them to .gitignore"
    echo "  3. Remove them from git: git rm --cached <file>"
    echo "  4. Run this script again"
    exit 1
fi

