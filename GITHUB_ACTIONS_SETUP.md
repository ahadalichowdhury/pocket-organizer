# 🤖 GitHub Actions Auto-Refresh Setup Guide

## 🎯 What This Does:

- ✅ Automatically refreshes FCM token **every hour**
- ✅ Updates MongoDB Atlas secret automatically
- ✅ Runs 24/7 without any manual work
- ✅ **FREE** on GitHub (2000 minutes/month free tier)
- ✅ Works like WhatsApp's backend (but serverless!)

---

## 📋 Prerequisites:

Before starting, make sure you have:

1. ✅ GitHub repository for your project
2. ✅ Firebase Service Account JSON file
3. ✅ MongoDB Atlas account with API access

---

## 🚀 Step-by-Step Setup:

### **Step 1: Get Firebase Service Account** (2 min)

1. Go to: https://console.firebase.google.com/
2. Select your project
3. Click **⚙️ Settings** → **Project Settings**
4. Go to **"Service accounts"** tab
5. Click **"Generate new private key"**
6. Download the JSON file
7. **Keep this file safe!**

---

### **Step 2: Get MongoDB Atlas API Keys** (3 min)

1. Go to: https://cloud.mongodb.com/
2. Click your profile (top right) → **"Organization Access Manager"**
3. Click **"API Keys"** tab
4. Click **"Create API Key"**
5. Fill in:
   - **Description**: `GitHub Actions FCM Refresh`
   - **Permissions**: `Organization Project Creator` (or `Organization Owner`)
6. Click **"Next"**
7. **Copy and save**:
   - **Public Key** (looks like: `abcdefgh`)
   - **Private Key** (looks like: `12345678-1234-1234-1234-123456789abc`)
8. Click **"Done"**

---

### **Step 3: Get MongoDB IDs** (2 min)

#### **3.1 Get Group ID (Project ID):**

1. In MongoDB Atlas, look at the URL when you're in your project:
   ```
   https://cloud.mongodb.com/v2/YOUR_GROUP_ID#/overview
                            6372747c7ebf26262a3410fc        ^^^^^^^^^^^^
   ```
2. Copy `YOUR_GROUP_ID` (24-character hex string)

#### **3.2 Get App ID:**

1. Go to **App Services** in MongoDB Atlas
2. Click on your app
3. Look at the URL:
   ```
   https://realm.mongodb.com/groups/GROUP_ID/apps/YOUR_APP_ID/dashboard
              68f76ebb3cbbe5a42294879f                                   ^^^^^^^^^^^^
   ```
4. Copy `YOUR_APP_ID` (24-character hex string)

---

### **Step 4: Add Secrets to GitHub** (5 min)

1. Go to your GitHub repository
2. Click **"Settings"** tab
3. In left sidebar, click **"Secrets and variables"** → **"Actions"**
4. Click **"New repository secret"**

Add these **5 secrets** one by one:

#### **Secret 1: FIREBASE_SERVICE_ACCOUNT_JSON**

- Name: `FIREBASE_SERVICE_ACCOUNT_JSON`
- Value: **Entire contents** of your Firebase service account JSON file
- Click "Add secret"

#### **Secret 2: MONGODB_PUBLIC_KEY**

- Name: `MONGODB_PUBLIC_KEY`
- Value: Your MongoDB Atlas API public key (from Step 2)
- Click "Add secret"

#### **Secret 3: MONGODB_PRIVATE_KEY**

- Name: `MONGODB_PRIVATE_KEY`
- Value: Your MongoDB Atlas API private key (from Step 2)
- Click "Add secret"

#### **Secret 4: MONGODB_GROUP_ID**

- Name: `MONGODB_GROUP_ID`
- Value: Your MongoDB project/group ID (from Step 3.1)
- Click "Add secret"

#### **Secret 5: MONGODB_APP_ID**

- Name: `MONGODB_APP_ID`
- Value: Your MongoDB App Services app ID (from Step 3.2)
- Click "Add secret"

---

### **Step 5: Commit GitHub Actions Workflow** (2 min)

The workflow file is already created at:

```
.github/workflows/refresh-fcm-token.yml
```

**Commit and push it:**

```bash
cd /Users/s.m.ahadalichowdhury/Downloads/project/pocket-organizer

git add .github/workflows/refresh-fcm-token.yml
git commit -m "Add FCM token auto-refresh workflow"
git push
```

---

### **Step 6: Test the Workflow** (1 min)

1. Go to your GitHub repository
2. Click **"Actions"** tab
3. Click **"Refresh FCM Access Token"** in the left sidebar
4. Click **"Run workflow"** button (top right)
5. Click **"Run workflow"** in the dropdown
6. Wait 30-60 seconds
7. **Check the results!**

#### **Expected Output:**

```
✅ Token generated: ya29...
📤 Updating fcm_access_token in MongoDB Atlas...
✅ Token updated successfully in MongoDB Atlas!
🔍 Verifying token was updated...
✅ Token verified in MongoDB Atlas
🎉 FCM Token refresh completed successfully!
Next refresh in 1 hour
```

---

## ✅ Verification:

### **Check MongoDB Atlas:**

1. Go to MongoDB Atlas → App Services → Your app
2. Left sidebar → **"Values"**
3. Find `fcm_access_token`
4. You should see: "Last Modified: X minutes ago"

### **Check GitHub Actions:**

1. GitHub → Actions tab
2. You should see a green checkmark ✅
3. Workflow will run automatically every hour

---

## 🎉 You're Done!

The FCM token will now automatically refresh **every hour** forever! 🚀

---

## 📊 How It Works:

```
Every Hour:
┌─────────────────────────────────────────┐
│  GitHub Actions Runner                  │
│  ┌───────────────────────────────────┐  │
│  │ 1. Authenticate with Firebase     │  │
│  │ 2. Generate OAuth token           │  │
│  │ 3. Call MongoDB Atlas API         │  │
│  │ 4. Update fcm_access_token secret │  │
│  │ 5. Verify update                  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
              ↓
    ┌──────────────────┐
    │  MongoDB Atlas   │
    │  fcm_access_token│ ← Always Fresh! ✅
    └──────────────────┘
              ↓
    ┌──────────────────┐
    │  MongoDB Trigger │
    │  Sends FCM       │ ← Works Forever! 🎉
    └──────────────────┘
```

---

## 🔧 Troubleshooting:

### **Error: "Authentication failed"**

→ **Fix**: Check that `MONGODB_PUBLIC_KEY` and `MONGODB_PRIVATE_KEY` are correct

### **Error: "App not found"**

→ **Fix**: Check that `MONGODB_GROUP_ID` and `MONGODB_APP_ID` are correct

### **Error: "Invalid service account"**

→ **Fix**: Check that `FIREBASE_SERVICE_ACCOUNT_JSON` contains valid JSON

### **Workflow not running automatically**

→ **Fix**: Make sure workflow file is in `.github/workflows/` directory

### **Want to change refresh frequency?**

Edit `.github/workflows/refresh-fcm-token.yml`:

```yaml
schedule:
  # Every 30 minutes:
  - cron: "*/30 * * * *"

  # Every 2 hours:
  - cron: "0 */2 * * *"

  # Every hour (current):
  - cron: "0 * * * *"
```

---

## 📈 Monitoring:

### **Email Notifications:**

GitHub can email you when the workflow fails:

1. GitHub → Settings → Notifications
2. Enable "Actions" notifications
3. You'll get emails if token refresh fails

### **Check Logs:**

1. GitHub → Actions tab
2. Click on any workflow run
3. See detailed logs of what happened

---

## 💰 Cost:

**FREE!** 🎉

- GitHub Actions: 2000 free minutes/month
- This workflow uses ~1 minute/hour = ~720 minutes/month
- Well within free tier!

---

## 🎯 Next Steps:

1. ✅ Push the workflow file to GitHub
2. ✅ Add all 5 secrets to GitHub
3. ✅ Test the workflow manually
4. ✅ Verify token was updated in MongoDB
5. ✅ Test FCM notifications in your app
6. 🎉 **Done! Token will refresh automatically forever!**

---

## 🚀 Final Test:

1. Add an expense in your app that crosses budget threshold
2. Check MongoDB Atlas Logs
3. Should see: "✅ FCM notification sent successfully!"
4. Check your phone for notification! 📱

**Now your app works like WhatsApp - notifications will work 24/7!** 🎉
