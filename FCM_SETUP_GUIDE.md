# FCM (Firebase Cloud Messaging) Setup Guide
## Making Budget Notifications Work Like WhatsApp on ALL Devices

---

## 🎯 **What This Achieves:**
✅ Budget notifications work on **ALL Android devices** (Xiaomi, OPPO, Realme, etc.)  
✅ Notifications work even when app is **completely closed**  
✅ **No user setup required** (no battery optimization settings)  
✅ **Instant delivery** via Google's infrastructure  
✅ Works exactly like WhatsApp/Facebook notifications  

---

## 📋 **Prerequisites:**
1. ✅ Firebase project already set up (you have `firebase_auth`)
2. ✅ MongoDB Atlas database with `pocket_organizer` database
3. ✅ `firebase_messaging` package added to `pubspec.yaml`

---

## 🔧 **Setup Steps:**

### **Step 1: Configure Android for FCM**

1. **Update `android/app/build.gradle`:**
```gradle
android {
    ...
    defaultConfig {
        ...
        minSdkVersion 21  // Required for FCM
        multiDexEnabled true
    }
}

dependencies {
    ...
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

2. **Verify `google-services.json` exists:**
   - Location: `android/app/google-services.json`
   - If missing, download from Firebase Console → Project Settings → Android App

---

### **Step 2: Enable FCM in Firebase Console**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Cloud Messaging** (left sidebar)
4. Enable **Firebase Cloud Messaging API (V1)**

---

### **Step 3: Set Up MongoDB Atlas App Services**

#### **3.1: Create Atlas App**
1. Go to [MongoDB Atlas](https://cloud.mongodb.com/)
2. Click **App Services** (left sidebar)
3. Click **Create a New App**
4. Name it `pocket-organizer-app`
5. Link it to your `pocket_organizer` database

#### **3.2: Enable Database Triggers**
1. In App Services, go to **Triggers** (left sidebar)
2. Click **Add a Trigger**
3. Configure:
   - **Trigger Type:** Database
   - **Name:** `ExpenseSyncTrigger`
   - **Enabled:** ON
   - **Cluster Name:** Your cluster name
   - **Database Name:** `pocket_organizer`
   - **Collection Name:** `expenses`
   - **Operation Types:** Select **Insert** and **Update**
   - **Full Document:** ON
   - **Document Preimage:** OFF
   - **Function:** (Create new function - see next step)

#### **3.3: Create Budget Check Function**
1. In Triggers setup, click **+ New Function**
2. Name it `checkBudgetAndSendAlert`
3. Copy the code from `mongodb_functions/checkBudgetAndSendAlert.js`
4. **Important: Replace `YOUR_PROJECT_ID`** with your Firebase project ID
5. Save the function

#### **3.4: Set Up FCM Service Account (Critical!)**

**Option A: Using Firebase Admin SDK (Recommended)**

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click **Generate New Private Key** (downloads a JSON file)
3. In MongoDB Atlas App Services:
   - Go to **Values & Secrets** (left sidebar)
   - Click **Create New Value**
   - Name: `fcm_service_account`
   - Type: Secret
   - Value: Paste the entire JSON content from the downloaded file
4. Update the MongoDB function to use Firebase Admin SDK:

```javascript
// In checkBudgetAndSendAlert.js
const admin = require('firebase-admin');

// Initialize Firebase Admin (add this at the top of the function)
if (!admin.apps.length) {
  const serviceAccount = JSON.parse(
    await context.values.get("fcm_service_account")
  );
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

// Replace sendFCMNotification function with:
async function sendFCMNotification({ fcmToken, title, body, data }) {
  const message = {
    token: fcmToken,
    notification: {
      title: title,
      body: body
    },
    data: data || {},
    android: {
      priority: 'high',
      notification: {
        channelId: 'budget_alerts',
        sound: 'default'
      }
    }
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log('✅ FCM notification sent:', response);
    return response;
  } catch (error) {
    console.error('❌ Error sending FCM:', error);
    throw error;
  }
}
```

**Option B: Using REST API with OAuth Token**

1. Set up OAuth 2.0 for server-to-server authentication
2. Store access token in MongoDB Atlas Values
3. Refresh token periodically (tokens expire after 1 hour)

---

### **Step 4: Create Collections**

Create these collections in MongoDB Atlas if they don't exist:

1. **`users`** collection:
```json
{
  "userId": "firebase_user_id",
  "fcmToken": "device_fcm_token",
  "fcmTokenUpdatedAt": "2024-01-15T10:30:00Z",
  "platform": "android"
}
```

2. **`budget_alerts`** collection (for deduplication):
```json
{
  "userId": "firebase_user_id",
  "budgetKey": "daily_budget",
  "amount": 450.50,
  "alertedAt": "2024-01-15T14:30:00Z",
  "period": "daily"
}
```

---

### **Step 5: Test the Integration**

#### **5.1: Test FCM Token Registration**
1. Build and run the app
2. Check logs for:
   ```
   ✅ [FCM] Token obtained: eF7j...
   ✅ [FCM] Token saved to MongoDB for user: abc123
   ```
3. Verify in MongoDB Atlas → Browse Collections → `users`:
   - Check if `fcmToken` field exists

#### **5.2: Test Expense Sync**
1. Add an expense in the app
2. Check MongoDB Atlas → Browse Collections → `expenses`:
   - Verify the expense was synced
3. Check App Services → Logs:
   - Should see "Checking budget for user: abc123"

#### **5.3: Test Budget Alert**
1. Set daily budget to a low amount (e.g., $10)
2. Add expenses totaling $8+ (crosses 80% threshold)
3. You should receive an FCM notification within seconds!

---

## 🔍 **Troubleshooting:**

### **Issue: No FCM token in MongoDB**
**Solution:**
- Check Firebase Console → Cloud Messaging is enabled
- Verify `google-services.json` is in `android/app/`
- Check app logs for FCM initialization errors

### **Issue: MongoDB trigger not firing**
**Solution:**
- Verify trigger is **Enabled** in App Services
- Check that collection name is exactly `expenses`
- Check App Services → Logs for errors

### **Issue: FCM notification not received**
**Solution:**
- Verify FCM token exists in MongoDB
- Check Firebase Admin SDK credentials are correct
- Test with FCM Composer in Firebase Console (send test notification)
- Check Android notification permissions are granted

### **Issue: Notifications work in foreground but not background**
**Solution:**
- This is normal! Background notifications are handled by FCM automatically
- Verify `@pragma('vm:entry-point')` is on background handler
- Check Android notification channel is created

---

## 📊 **Architecture Flow:**

```
User adds expense in app
    ↓
Expense synced to MongoDB
    ↓
MongoDB Trigger fires
    ↓
checkBudgetAndSendAlert() function executes
    ↓
Calculates spent amount for daily/weekly/monthly
    ↓
Checks if threshold crossed
    ↓
If YES → Sends FCM notification via Firebase Admin SDK
    ↓
Google Play Services delivers notification to device
    ↓
User receives notification (even if app is closed!)
```

---

## ✅ **Verification Checklist:**

- [ ] Firebase project configured
- [ ] `google-services.json` in `android/app/`
- [ ] FCM enabled in Firebase Console
- [ ] MongoDB Atlas App Services created
- [ ] Database trigger configured
- [ ] Budget check function deployed
- [ ] FCM service account set up
- [ ] Collections created (`users`, `budget_alerts`)
- [ ] App tested and FCM token saved
- [ ] Test notification received

---

## 🎉 **Result:**

Once set up, budget notifications will work **exactly like WhatsApp**:
- ✅ Works on ALL Android devices (Xiaomi, OPPO, Realme, etc.)
- ✅ No user configuration required
- ✅ Notifications arrive instantly
- ✅ Works even when app is completely closed
- ✅ Battery efficient (managed by Google Play Services)

---

## 📞 **Support:**

If you encounter issues:
1. Check MongoDB Atlas → App Services → Logs
2. Check Firebase Console → Cloud Messaging → Diagnostics
3. Use FCM test tool: https://firebase.google.com/docs/cloud-messaging/send-message#send_a_test_notification_message

---

**This is the industry-standard solution used by WhatsApp, Facebook, Instagram, Gmail, and all major apps!**


