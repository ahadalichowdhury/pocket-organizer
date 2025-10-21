# ⚡ Quick Fix: MongoDB Trigger Error

## 🔴 Error You're Seeing:
```
TypeError: Cannot access member 'GOOGLE_SDK_NODE_LOGGING' of undefined
```

## ✅ Quick Fix (5 minutes):

### **1. Remove firebase-admin Dependency**

Go to: **MongoDB Atlas → App Services → Dependencies**

- Find `firebase-admin`
- Click 🗑️ (trash icon)
- Click **"Save"** → **"Review & Deploy"** → **"Deploy"**

---

### **2. Update Function Code**

Go to: **MongoDB Atlas → App Services → Functions → checkBudgetAndSendAlert**

- **Delete all code**
- **Copy & paste** code from: `/mongodb_functions/checkBudgetAndSendAlert_v2_legacy_api.js`
- Click **"Save"** → **"Review & Deploy"** → **"Deploy"**

---

### **3. Get FCM Server Key**

1. Go to: https://console.firebase.google.com/
2. Select your project → ⚙️ Settings → **Project Settings**
3. Go to **"Cloud Messaging"** tab
4. Copy **"Server key"** (under "Cloud Messaging API (Legacy)")

---

### **4. Add Secret to MongoDB**

Go to: **MongoDB Atlas → App Services → Values**

- Click **"Create New Value"**
- **Name**: `fcm_server_key`
- **Type**: Secret
- **Value**: Paste your FCM Server Key
- Click **"Save"** → **"Review & Deploy"** → **"Deploy"**

---

### **5. Test It**

1. Open your app
2. Add an expense that crosses your budget threshold
3. Check: **MongoDB Atlas → App Services → Logs**
4. You should see: `✅ Sent [period] budget alert`

---

## 🎉 Done!

Your trigger will now work without the `firebase-admin` error!

---

## 🆘 Still Having Issues?

Read the detailed fix guide: `MONGODB_TRIGGER_FIX.md`

