# MongoDB Atlas App Services Setup Guide

## Setting Up Automatic Budget Notifications (Like WhatsApp)

---

## 🎯 **What We're Setting Up:**

Automatic backend system that:

- Monitors when expenses are synced to MongoDB
- Checks if budget thresholds are crossed
- Sends FCM notifications automatically
- Works even when app is closed

---

## 📋 **Prerequisites:**

✅ Firebase service account JSON file downloaded  
✅ MongoDB Atlas account with `pocket_organizer` database  
✅ Expenses are already syncing to MongoDB

---

## 🚀 **Step-by-Step Setup:**

---

### **STEP 1: Access MongoDB Atlas**

1. Go to: https://cloud.mongodb.com/
2. Log in to your account
3. Select your project (where `pocket_organizer` database exists)

---

### **STEP 2: Create App Services Application**

1. **In the left sidebar**, click **"App Services"**
2. **Click the green button**: `+ Create a New App`

3. **Fill in the form:**

   - **App Name**: `pocket-organizer-app`
   - **Link to Data Source**: Select your cluster (e.g., `Cluster0`)
   - **Deployment Model**: Select `Global`
   - **Deployment Location**: Choose closest region to you

4. **Click**: `Create App Services`

5. **Wait** for deployment (30-60 seconds)

---

### **STEP 3: Create Database Trigger**

1. **In App Services dashboard**, click **"Triggers"** in left sidebar

2. **Click**: `Add a Trigger`

3. **Configure the trigger:**

   **Trigger Configuration:**

   - **Trigger Type**: `Database` (should be pre-selected)
   - **Name**: `ExpenseSyncTrigger`
   - **Enabled**: Toggle ON ✅

   **Linked Data Source:**

   - **Cluster Name**: Your cluster (e.g., `Cluster0`)
   - **Database Name**: `pocket_organizer`
   - **Collection Name**: `expenses`

   **Operation Types:** Check ✅ both:

   - [x] Insert
   - [x] Update
   - [ ] Delete (leave unchecked)
   - [ ] Replace (leave unchecked)

   **Full Document**: Toggle ON ✅

   **Document Preimage**: Toggle OFF

   **Select An Event Type**: `Function`

4. **Don't save yet!** We need to create the function first.

---

### **STEP 4: Create the Function\*\***

1. **While still on the trigger page**, under **"Function"** section
2. **Click**: `+ New Function`
3. **Function Name**: `checkBudgetAndSendAlert`
4. **Click**: `Save` (creates empty function)

5. **Now you'll see a code editor**

6. **Delete the default code** and **paste this:**

```javascript

```

7. **Click**: `Save` (bottom right)

---

### **STEP 5: Upload Firebase Service Account as Secret**

1. **In left sidebar**, click **"Values"**

2. **Click**: `Create New Value`

3. **Configure:**

   - **Value Name**: `fcm_service_account`
   - **Value Type**: Select `Secret`
   - **Value**:
     - Open your downloaded Firebase JSON file (e.g., `pocket-organizer-firebase-adminsdk.json`)
     - **Copy the ENTIRE contents** (from `{` to `}`)
     - Paste into the text box

4. **Click**: `Save`

5. **You'll see a warning**: "This secret will be encrypted and cannot be viewed again"
   - **Click**: `I Understand`

---

### **STEP 6: Install Firebase Admin Dependency**

1. **In left sidebar**, click **"Dependencies"**

2. **Click**: `Add Dependency`

3. **Add:**

   - **Package Name**: `firebase-admin`
   - **Version**: (leave blank for latest, or use `12.0.0`)

4. **Click**: `Add`

5. **Click**: `Save` (at the bottom)

6. **Wait** for dependencies to install (~30 seconds)

---

### **STEP 7: Finish Trigger Setup**

1. **Go back to "Triggers"** in left sidebar

2. **Click** on your `ExpenseSyncTrigger`

3. **Verify configuration:**

   - Enabled: ✅ ON
   - Database: `pocket_organizer`
   - Collection: `expenses`
   - Function: `checkBudgetAndSendAlert`

4. **Click**: `Save` (bottom right)

---

### **STEP 8: Deploy Changes**

1. **Top of the page**, you'll see: `REVIEW DRAFT & DEPLOY`

2. **Click**: `REVIEW DRAFT & DEPLOY`

3. **Review your changes:**

   - New trigger created
   - New function created
   - New secret added
   - New dependency added

4. **Click**: `Deploy`

5. **Wait** for deployment (30-60 seconds)

6. **Success!** You'll see: "Deployment successful"

---

### **STEP 9: Create Required Collections (If Not Exist)**

1. **Go to MongoDB Atlas** (not App Services)

2. **Click "Browse Collections"**

3. **Check if these collections exist in `pocket_organizer` database:**

   - `users`
   - `user_settings`
   - `expenses`
   - `budget_alerts`

4. **If any are missing, create them:**
   - Click **"Create Collection"**
   - Enter collection name
   - Click **"Create"**

---

## ✅ **Verification Steps:**

### **Test 1: Check if Trigger is Active**

1. Go to App Services → **Triggers**
2. You should see:
   - `ExpenseSyncTrigger` with green dot ✅
   - Status: "Enabled"

### **Test 2: Check Function Logs**

1. Go to App Services → **Logs** (left sidebar)
2. You should see recent logs (if any expenses were synced)

### **Test 3: Test with Your App**

1. **Build and run your app**
2. **Check logs** for:
   ```
   ✅ [FCM] Token obtained: eF7j...
   ✅ [FCM] Token saved to MongoDB
   ```
3. **Add an expense** that crosses your budget threshold
4. **Wait 5-10 seconds**
5. **You should receive a notification!** 🎉

---

## 🐛 **Troubleshooting:**

### **Issue: No notification received**

**Check 1: FCM Token Saved?**

- MongoDB Atlas → Browse Collections → `users`
- Find your userId
- Check if `fcmToken` field exists

**Check 2: Trigger Fired?**

- App Services → Logs
- Look for: "Checking budget for user: xxx"
- If not present, trigger didn't fire

**Check 3: Budget Threshold Crossed?**

- App Services → Logs
- Look for: "daily budget: { budget: 100, totalSpent: 85, ... }"
- Check if `shouldAlert: true`

**Check 4: Firebase Admin Working?**

- App Services → Logs
- Look for: "Firebase Admin initialized"
- If error, check service account JSON is correct

---

## 🎉 **Setup Complete!**

Your budget notifications will now work **exactly like WhatsApp**:

- ✅ Automatic (no manual intervention)
- ✅ Works on ALL devices (Xiaomi, OPPO, Realme, etc.)
- ✅ Works when app is closed
- ✅ Instant delivery via Google Play Services
- ✅ No battery optimization issues

---

## 📱 **Next Steps:**

1. Build the APK with FCM support
2. Test on a real device
3. Add expenses and watch for notifications!

---

**Need help with any step? Let me know which step you're on!** 🚀
