# ⚡ Quick Start: FCM V1 API Migration

## 🎯 What You Need to Do:

1. Download Service Account JSON
2. Generate Access Token
3. Add 2 values to MongoDB Atlas
4. Update MongoDB Function
5. Test!

---

## 📝 Step-by-Step (5 Minutes):

### **1. Download Service Account** (2 min)

1. Go to: https://console.firebase.google.com/
2. Your project → ⚙️ Settings → Project Settings
3. Tab: "Service accounts"
4. Click: **"Generate new private key"**
5. Click: **"Generate key"**
6. Save the JSON file

**While you're here, copy:**

- Project ID (e.g., `pocket-organizer-12345`)

---

### **2. Install gcloud CLI** (if needed)

**Mac:**

```bash
brew install google-cloud-sdk
```

**Windows:**
Download from: https://cloud.google.com/sdk/docs/install

**Linux:**

```bash
curl https://sdk.cloud.google.com | bash
```

---

### **3. Generate Access Token** (1 min)

```bash
# Authenticate
gcloud auth activate-service-account --key-file=path/to/your-downloaded-file.json

# Get token
gcloud auth print-access-token
```

**Copy the output** (long string starting with `ya29.`)

---

### **4. Add to MongoDB Atlas** (2 min)

Go to: **MongoDB Atlas → App Services → Your App → Values**

#### **Add Value #1:**

- Click "Create New Value"
- Name: `firebase_project_id`
- Type: `Secret`
- Value: Your project ID (e.g., `pocket-organizer-12345`)
- Save

#### **Add Value #2:**

- Click "Create New Value"
- Name: `fcm_access_token`
- Type: `Secret`
- Value: Paste the token from step 3
- Save

Click: **"Review Draft & Deploy"** → **"Deploy"**

---

### **5. Update Function** (1 min)

1. MongoDB Atlas → Functions → `checkBudgetAndSendAlert`
2. **Delete all code**
3. Copy code from: `/mongodb_functions/checkBudgetAndSendAlert_V1_SIMPLE.js`
4. Paste
5. Save → Review & Deploy → Deploy

---

### **6. Test!** (1 min)

1. Open your app
2. Add an expense that crosses budget threshold
3. Check MongoDB Atlas → Logs
4. Should see: "✅ FCM notification sent successfully!"
5. Check your phone for notification! 🎉

---

## ⚠️ Important Notes:

**Access Token Expires:**

- Token lasts 1 hour
- For testing: Regenerate when needed
- For production: Set up auto-refresh (see full guide)

**To Regenerate Token:**

```bash
gcloud auth print-access-token
```

Then update `fcm_access_token` in MongoDB Atlas Values.

---

## 🐛 Troubleshooting:

**"invalid_grant" error:**
→ Token expired. Regenerate with `gcloud auth print-access-token`

**"Project not found":**
→ Check `firebase_project_id` is correct

**"No FCM token found":**
→ Run the app with `UserSyncService` fix (see main README)

---

## 📚 Full Documentation:

Read: **`FCM_V1_API_MIGRATION.md`** for:

- Auto token refresh setup
- Production deployment
- GitHub Actions integration
- Advanced configurations

---

## ✅ Checklist:

- [ ] Downloaded service account JSON
- [ ] Installed gcloud CLI
- [ ] Generated access token
- [ ] Added `firebase_project_id` to MongoDB
- [ ] Added `fcm_access_token` to MongoDB
- [ ] Deployed and deployed changes
- [ ] Updated MongoDB function
- [ ] Tested with expense
- [ ] Received notification!

---

**You're all set!** 🚀

If notifications aren't arriving, check the MongoDB logs for detailed error messages.
