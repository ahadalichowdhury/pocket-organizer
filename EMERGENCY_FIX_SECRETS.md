# 🚨 EMERGENCY: Fix Exposed Secrets in GitHub

## ⚠️ CRITICAL - ACT NOW!

GitHub detected sensitive credentials in your repository. **Anyone can see these now!**

---

## 🔥 Immediate Actions Required:

### **Phase 1: STOP THE DAMAGE (5 minutes)**

1. **Go to your GitHub repository**
2. **Make it PRIVATE immediately:**
   - Go to: Settings → Danger Zone → Change visibility
   - Click "Make private"
   - Confirm

This prevents new people from seeing the secrets while we fix it.

---

### **Phase 2: REMOVE SECRETS FROM HISTORY (10 minutes)**

The secrets are in git history, so we need to rewrite history to remove them.

#### **Files to Clean:**

1. `ios/Runner/GoogleService-Info.plist`
2. `lib/firebase_options.dart`
3. `ENV_SETUP.md`
4. `.env.example`

#### **Method 1: Using BFG Repo Cleaner** (Easiest)

```bash
cd /Users/s.m.ahadalichowdhury/Downloads/project/pocket-organizer

# Install BFG (if not installed)
brew install bfg  # macOS
# or download from: https://rtyley.github.io/bfg-repo-cleaner/

# Create a backup first!
cd ..
cp -r pocket-organizer pocket-organizer-backup

cd pocket-organizer

# Remove GoogleService-Info.plist from all history
bfg --delete-files GoogleService-Info.plist

# Remove sensitive lines from firebase_options.dart
# Create a passwords.txt file with the API keys
echo "YOUR_API_KEY_HERE" > passwords.txt
echo "YOUR_MONGODB_CONNECTION_STRING" >> passwords.txt
bfg --replace-text passwords.txt

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push to rewrite history
git push --force origin main
```

#### **Method 2: Using git filter-branch** (Alternative)

```bash
cd /Users/s.m.ahadalichowdhury/Downloads/project/pocket-organizer

# Backup first!
cd ..
cp -r pocket-organizer pocket-organizer-backup
cd pocket-organizer

# Remove GoogleService-Info.plist from history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch ios/Runner/GoogleService-Info.plist" \
  --prune-empty --tag-name-filter cat -- --all

# Remove .env.example from history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env.example" \
  --prune-empty --tag-name-filter cat -- --all

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push
git push --force origin main
```

---

### **Phase 3: REGENERATE ALL CREDENTIALS (15 minutes)**

All exposed credentials MUST be regenerated:

#### **1. Firebase API Keys**

**Option A: Create New Firebase Project** (Recommended)

- Go to: https://console.firebase.google.com/
- Create a NEW project with different name
- Set up FCM for the new project
- Download new GoogleService-Info.plist
- Run: `flutterfire configure` to regenerate firebase_options.dart

**Option B: Rotate Keys in Existing Project**

- Firebase Console → Project Settings → General
- Scroll to "Your apps"
- Delete the iOS app
- Re-add the iOS app
- Download new GoogleService-Info.plist

#### **2. MongoDB Connection String**

1. Go to: https://cloud.mongodb.com/
2. Navigate to: Database Access
3. **Change database password:**
   - Click on your user
   - Edit Password
   - Generate new strong password
   - Update password
4. **Update connection string** in your local `.env` file (NOT in git!)

#### **3. Google API Keys**

1. Go to: https://console.cloud.google.com/apis/credentials
2. Find the exposed API key
3. Click on it
4. Click "Delete" or "Regenerate"
5. Create a new API key if needed

---

### **Phase 4: SECURE FILES PROPERLY (5 minutes)**

#### **Update .gitignore** (Already done ✅)

Your `.gitignore` is updated, but let's add more:

```bash
# Add these to .gitignore if not already there
echo "ios/Runner/GoogleService-Info.plist" >> .gitignore
echo ".env.example" >> .gitignore
echo "ENV_SETUP.md" >> .gitignore
```

#### **Remove Sensitive Files from Tracking**

```bash
# Remove from git but keep local copies
git rm --cached ios/Runner/GoogleService-Info.plist
git rm --cached .env.example
git rm --cached ENV_SETUP.md

# Commit the removal
git add .gitignore
git commit -m "chore: Remove sensitive files and update gitignore"
git push
```

#### **Create Safe Example Files**

Create `GoogleService-Info.plist.example`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key>
  <string>REPLACE_WITH_YOUR_API_KEY</string>
  <!-- Add other keys without real values -->
</dict>
</plist>
```

Update `.env.example`:

```bash
# MongoDB Configuration (EXAMPLE - Replace with your own)
MONGODB_CONNECTION_STRING=mongodb+srv://YOUR_USERNAME:YOUR_PASSWORD@YOUR_CLUSTER.mongodb.net/YOUR_DATABASE
MONGODB_DATABASE_NAME=your_database_name

# IMPORTANT: Copy this file to .env and fill in real values
# Never commit the actual .env file!
```

Update `ENV_SETUP.md` - remove actual connection strings, show only format.

---

### **Phase 5: VERIFY CLEANUP (2 minutes)**

```bash
# Check git history for secrets
git log --all --full-history --source -- ios/Runner/GoogleService-Info.plist

# Should return nothing if cleaned properly

# Check current files
git status

# Make sure sensitive files are not tracked
git ls-files | grep -E "(GoogleService-Info.plist|.env.example|ENV_SETUP.md)"

# Should return nothing or only .example files
```

---

## ✅ Final Checklist:

- [ ] Repository set to PRIVATE
- [ ] Secrets removed from git history
- [ ] Force pushed cleaned history
- [ ] Firebase project recreated OR keys rotated
- [ ] MongoDB password changed
- [ ] Google API keys regenerated
- [ ] Sensitive files in .gitignore
- [ ] Safe example files created
- [ ] Verified cleanup successful
- [ ] GitHub secret alerts dismissed

---

## 🔒 Going Forward:

### **NEVER commit these files:**

- `GoogleService-Info.plist`
- `google-services.json`
- `.env` (any environment files)
- `firebase_options.dart` (if it has real values)
- Any file with actual credentials

### **Always use:**

- `.env` for local secrets (in .gitignore)
- `.example` files for documentation
- GitHub Secrets for CI/CD credentials
- MongoDB Atlas secrets for production

---

## 📞 Priority Order:

1. **NOW**: Make repo private
2. **NEXT 5 MIN**: Remove secrets from git history
3. **NEXT 15 MIN**: Regenerate ALL exposed credentials
4. **NEXT 5 MIN**: Update .gitignore and create example files
5. **FINALLY**: Verify everything is clean

---

## 🆘 If You're Stuck:

1. Make repo private FIRST (most important!)
2. Contact me for help with git history cleanup
3. Don't push anything until secrets are removed

---

**START NOW! Every second counts!** ⏰

The longer exposed secrets remain valid, the higher the risk of unauthorized access.
