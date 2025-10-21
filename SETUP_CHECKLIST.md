# ✅ FCM Auto-Refresh Setup Checklist

## 📝 Follow These Steps in Order:

### **Phase 1: Get Credentials** (10 minutes)

- [ ] **Download Firebase Service Account JSON**

  - Go to Firebase Console → Project Settings → Service Accounts
  - Click "Generate new private key"
  - Save the JSON file securely

- [ ] **Create MongoDB Atlas API Keys**

  - MongoDB Atlas → Organization Access Manager → API Keys
  - Create new API key
  - Save Public Key and Private Key

- [ ] **Get MongoDB Group ID**

  - Look at MongoDB Atlas URL
  - Copy the 24-character group ID

- [ ] **Get MongoDB App ID**
  - MongoDB Atlas → App Services → Your app
  - Copy the 24-character app ID from URL

---

### **Phase 2: Add GitHub Secrets** (5 minutes)

Go to: **GitHub Repository → Settings → Secrets and variables → Actions**

- [ ] Add secret: `FIREBASE_SERVICE_ACCOUNT_JSON`
- [ ] Add secret: `MONGODB_PUBLIC_KEY`
- [ ] Add secret: `MONGODB_PRIVATE_KEY`
- [ ] Add secret: `MONGODB_GROUP_ID`
- [ ] Add secret: `MONGODB_APP_ID`

---

### **Phase 3: Deploy Workflow** (2 minutes)

```bash
cd /Users/s.m.ahadalichowdhury/Downloads/project/pocket-organizer

# Stage the workflow file
git add .github/workflows/refresh-fcm-token.yml

# Commit
git commit -m "Add FCM token auto-refresh workflow"

# Push to GitHub
git push
```

- [ ] Workflow file committed
- [ ] Workflow file pushed to GitHub

---

### **Phase 4: Initial Setup** (5 minutes)

- [ ] **Generate first token manually:**

  ```bash
  # Authenticate
  gcloud auth activate-service-account --key-file=path/to/service-account.json

  # Get token
  gcloud auth print-access-token
  ```

- [ ] **Add token to MongoDB Atlas:**

  - MongoDB Atlas → App Services → Values
  - Create new value: `fcm_access_token` (type: Secret)
  - Paste the token
  - Save and deploy

- [ ] **Add Project ID to MongoDB Atlas:**

  - Create new value: `firebase_project_id` (type: Secret)
  - Value: Your Firebase project ID
  - Save and deploy

- [ ] **Upload V1 MongoDB Function:**
  - MongoDB Atlas → App Services → Functions
  - Update `checkBudgetAndSendAlert`
  - Use code from: `checkBudgetAndSendAlert_V1_SIMPLE.js`
  - Save and deploy

---

### **Phase 5: Test** (5 minutes)

- [ ] **Test GitHub Action manually:**

  - Go to GitHub → Actions tab
  - Click "Refresh FCM Access Token"
  - Click "Run workflow"
  - Wait and check for green checkmark ✅

- [ ] **Verify in MongoDB Atlas:**

  - Check `fcm_access_token` was updated
  - Check "Last Modified" timestamp

- [ ] **Test FCM notification:**
  - Open your app
  - Add expense that crosses budget
  - Check MongoDB Logs
  - Check phone for notification 📱

---

## 🎯 Success Criteria:

✅ GitHub Action runs successfully  
✅ Token updates in MongoDB Atlas  
✅ MongoDB Trigger sends notification  
✅ Notification arrives on phone

---

## 📚 Documentation:

- **Full Setup Guide**: `GITHUB_ACTIONS_SETUP.md`
- **FCM V1 Migration**: `FCM_V1_API_MIGRATION.md`
- **Quick Start**: `FCM_V1_QUICK_START.md`
- **Workflow File**: `.github/workflows/refresh-fcm-token.yml`
- **MongoDB Function**: `mongodb_functions/checkBudgetAndSendAlert_V1_SIMPLE.js`

---

## ⏰ Timeline:

- Setup: **15-30 minutes** (one-time)
- After that: **Automatic forever!** ✅

---

## 🆘 Need Help?

If stuck on any step:

1. Check the full guide: `GITHUB_ACTIONS_SETUP.md`
2. Look at MongoDB Atlas Logs for errors
3. Check GitHub Actions logs for failures

---

## 🎉 Once Complete:

You'll have a production-ready FCM notification system that:

- ✅ Works 24/7
- ✅ Auto-refreshes tokens
- ✅ Costs $0
- ✅ Requires zero maintenance

**Just like WhatsApp, but serverless!** 🚀
