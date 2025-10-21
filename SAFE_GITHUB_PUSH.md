# 🚀 Push to GitHub - Safe Checklist

## ⚠️ CRITICAL: Before You Push!

### **1. Check for Sensitive Files** ✅

Run this command to see what will be committed:

```bash
cd /Users/s.m.ahadalichowdhury/Downloads/project/pocket-organizer

# See all files that will be committed
git status

# See what changes will be committed
git diff --cached
```

### **2. Verify These Files Are NOT in the commit:**

❌ **NEVER commit these:**
- Firebase service account JSON files
- `.env` files
- MongoDB credentials
- API keys
- `google-services.json.backup`
- Any file with passwords or secrets

✅ **These are SAFE to commit:**
- Source code (`.dart`, `.js` files)
- Documentation (`.md` files)
- GitHub Actions workflow (`.github/workflows/`)
- Configuration files (without secrets)
- `pubspec.yaml`, `package.json`

---

## 🔍 Quick Scan for Sensitive Data

Run these commands to check:

```bash
# Check for service account files
find . -name "*service-account*.json" -o -name "*adminsdk*.json"

# Check for .env files
find . -name ".env*"

# Check for hardcoded API keys in code
grep -r "AAAA" lib/ --include="*.dart"
grep -r "sk-proj" lib/ --include="*.dart"
grep -r "mongodb+srv" lib/ --include="*.dart"
```

**If any of these return results**: Make sure they're in `.gitignore`!

---

## ✅ Safe Push Procedure

### **Step 1: Initial Check**

```bash
# See current status
git status

# Check .gitignore is working
git check-ignore -v build/
git check-ignore -v .env
```

### **Step 2: Stage Files**

```bash
# Stage all files (respects .gitignore)
git add .

# Or stage specific files/directories
git add lib/
git add .github/
git add pubspec.yaml
git add *.md
```

### **Step 3: Review What Will Be Committed**

```bash
# See list of files to be committed
git status

# See actual changes
git diff --staged
```

### **Step 4: Commit**

```bash
# Commit with a meaningful message
git commit -m "Initial commit: Flutter app with FCM notifications and MongoDB integration"
```

### **Step 5: Push to GitHub**

```bash
# If this is first push to a new repo
git remote add origin https://github.com/YOUR_USERNAME/pocket-organizer.git
git branch -M main
git push -u origin main

# If repo already exists
git push
```

---

## 🛡️ Security Double-Check

### **After pushing, verify on GitHub:**

1. Go to your GitHub repository
2. **Check these files are NOT there:**
   - ❌ `firebase-adminsdk-*.json`
   - ❌ `.env` files
   - ❌ `google-services.json.backup`
   - ❌ Any credentials

3. **Check these files ARE there:**
   - ✅ `.gitignore`
   - ✅ `lib/` directory
   - ✅ `.github/workflows/refresh-fcm-token.yml`
   - ✅ Documentation files

---

## ⚠️ If You Accidentally Committed Secrets

### **DON'T PANIC! Fix it:**

```bash
# Remove file from git (keeps local copy)
git rm --cached path/to/secret-file.json

# Commit the removal
git commit -m "Remove sensitive file"

# Force push to overwrite history
git push -f origin main
```

### **Then:**

1. **Regenerate ALL exposed credentials** immediately:
   - New Firebase service account
   - New MongoDB API keys
   - New Firebase project (if API keys exposed)

2. **Add the file to .gitignore**:
```bash
echo "secret-file.json" >> .gitignore
git add .gitignore
git commit -m "Add secret file to gitignore"
git push
```

---

## 📋 Pre-Push Checklist

Use this before EVERY push:

- [ ] Ran `git status` to see what's being committed
- [ ] Checked no `.env` files in commit
- [ ] Checked no `*service-account*.json` files in commit
- [ ] Checked no hardcoded API keys in code
- [ ] `.gitignore` is up to date
- [ ] Sensitive files are in `.gitignore`
- [ ] Commit message is meaningful
- [ ] Ready to push!

---

## 🎯 Recommended Git Commands

### **Safe Workflow:**

```bash
# 1. Check status
git status

# 2. Add specific files (safer than git add .)
git add lib/
git add pubspec.yaml
git add .github/
git add *.md

# 3. Review changes
git diff --staged

# 4. Commit
git commit -m "Your message"

# 5. Push
git push
```

### **Useful Commands:**

```bash
# See what's ignored
git status --ignored

# Check if a file is ignored
git check-ignore -v filename

# Undo last commit (keeps changes)
git reset --soft HEAD~1

# Undo git add (unstage files)
git reset
```

---

## 🔐 What's Already Protected

Your `.gitignore` now protects:

✅ Firebase service accounts  
✅ Environment files (`.env`)  
✅ MongoDB credentials  
✅ Build artifacts  
✅ Generated files  
✅ IDE settings  
✅ Log files  
✅ Temporary files  

---

## 🚀 You're Ready to Push!

Now you can safely push to GitHub:

```bash
git add .
git commit -m "feat: Add FCM notifications with MongoDB integration"
git push
```

**All your secrets are safe!** 🔒

