# 🔧 MongoDB Atlas Trigger Error Fix

## ❌ The Problem

You're seeing this error in your MongoDB Atlas Trigger:
```
TypeError: Cannot access member 'GOOGLE_SDK_NODE_LOGGING' of undefined
```

This happens because:
- MongoDB Atlas Functions have a **restricted runtime environment**
- The `firebase-admin` package tries to access Node.js environment variables that **don't exist** in MongoDB Atlas
- Specifically, `google-logging-utils` tries to access `process.env.GOOGLE_SDK_NODE_LOGGING` which is undefined

## ✅ The Solution

**Remove `firebase-admin` dependency completely** and use MongoDB's built-in HTTP client instead.

---

## 🚀 Step-by-Step Fix

### **STEP 1: Remove firebase-admin Dependency**

1. Go to **MongoDB Atlas → App Services → Your App**
2. In the left sidebar, click **"Dependencies"**
3. Find `firebase-admin` in the list
4. Click the **trash icon** 🗑️ next to it
5. Click **"Save"** at the top
6. Click **"Review Draft & Deploy"**
7. Click **"Deploy"**

---

### **STEP 2: Update the Function Code**

1. In the left sidebar, click **"Functions"**
2. Click on `checkBudgetAndSendAlert` function
3. **Delete ALL existing code**
4. **Paste the new code** from `/mongodb_functions/checkBudgetAndSendAlert.js`
5. Click **"Save"** at the bottom
6. Click **"Review Draft & Deploy"**
7. Click **"Deploy"**

---

### **STEP 3: Create FCM Access Token Secret**

Since we can't use `firebase-admin`, we need to manually provide an OAuth 2.0 access token.

#### **Option A: Manual Token (Quick but expires in 1 hour)**

1. **Get a temporary token:**
   - Install Firebase CLI: `npm install -g firebase-tools`
   - Run: `firebase login:ci`
   - Or use: https://console.firebase.google.com/ → Project Settings → Service accounts → Generate new private key

2. **Get OAuth Token from Service Account:**
```bash
# Install gcloud CLI if not installed
# Then authenticate with your service account JSON:

gcloud auth activate-service-account --key-file=YOUR_SERVICE_ACCOUNT.json
gcloud auth print-access-token
```

3. **Copy the token** (starts with `ya29.`)

4. **In MongoDB Atlas:**
   - Go to **Values** in left sidebar
   - Click **"Create New Value"**
   - **Value Name**: `fcm_access_token`
   - **Value Type**: `Secret`
   - **Value**: Paste your token
   - Click **"Save"**

⚠️ **Note**: This token expires in 1 hour. For production, use Option B.

---

#### **Option B: Use HTTP API with Server Key (Recommended for testing)**

If you want a simpler approach for testing:

1. **Get your FCM Server Key:**
   - Go to: https://console.firebase.google.com/
   - Select your project
   - Click ⚙️ Settings → Project Settings
   - Go to **"Cloud Messaging"** tab
   - Copy **"Server key"** (under Cloud Messaging API - Legacy)

2. **Update the function to use Legacy API:**

Replace the `sendFCMNotification` function in your MongoDB function with:

```javascript
async function sendFCMNotification({ fcmToken, title, body, data }) {
  const fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';
  
  // Get server key from MongoDB Atlas Secret
  const serverKey = await context.values.get("fcm_server_key");
  
  const message = {
    to: fcmToken,
    notification: {
      title: title,
      body: body
    },
    data: data || {},
    priority: 'high',
    android: {
      priority: 'high',
      notification: {
        channel_id: 'budget_alerts',
        sound: 'default'
      }
    }
  };
  
  try {
    const response = await context.http.post({
      url: fcmEndpoint,
      headers: {
        'Authorization': [`key=${serverKey}`],
        'Content-Type': ['application/json']
      },
      body: JSON.stringify(message)
    });
    
    console.log('FCM response:', response.body.text());
    return response;
  } catch (error) {
    console.error('Error sending FCM:', error);
    throw error;
  }
}

async function getFCMAccessToken() {
  // Not needed for legacy API
  return null;
}
```

3. **Create the secret in MongoDB Atlas:**
   - Go to **Values** → **"Create New Value"**
   - **Value Name**: `fcm_server_key`
   - **Value Type**: `Secret`
   - **Value**: Your FCM Server Key
   - Click **"Save"**

---

### **STEP 4: Test the Trigger**

1. **Open your Pocket Organizer app**
2. **Add a new expense** that will trigger a budget alert
3. **Check MongoDB Atlas logs:**
   - Go to **App Services → Logs** in left sidebar
   - Look for recent logs from `ExpenseSyncTrigger`
   - Should see: `✅ Sent [period] budget alert to user [userId]`

---

## 🔍 **Why This Works**

| ❌ Old Approach | ✅ New Approach |
|----------------|----------------|
| Uses `firebase-admin` NPM package | Uses MongoDB's `context.http` API |
| Requires Node.js environment | Works in restricted Atlas environment |
| Automatic OAuth token refresh | Uses server key (doesn't expire) |
| Complex dependency chain | Zero dependencies |
| Breaks in Atlas Functions | Native Atlas functionality |

---

## 📊 **Verify It's Working**

1. **Check Trigger Status:**
   - MongoDB Atlas → App Services → Triggers
   - `ExpenseSyncTrigger` should show **green checkmark** ✅

2. **View Recent Executions:**
   - Click on the trigger name
   - Scroll down to **"Execution History"**
   - Should see recent successful executions

3. **Check Logs:**
   - App Services → Logs
   - Filter by: `Function: checkBudgetAndSendAlert`
   - Look for console.log outputs

---

## 🐛 **Still Having Issues?**

### Error: "Cannot access member 'GOOGLE_SDK_NODE_LOGGING'"
- **Solution**: Make sure you removed `firebase-admin` from Dependencies and deployed

### Error: "fcm_server_key is not defined"
- **Solution**: Create the Value/Secret in MongoDB Atlas (Step 3)

### No notification received
- **Check**: User's FCM token is saved in MongoDB `users` collection
- **Check**: User has budget limits set in `user_settings` collection
- **Check**: Expense amount actually crosses the threshold

---

## 🎯 **Summary**

**What we changed:**
1. ❌ Removed `firebase-admin` dependency
2. ✅ Use MongoDB's built-in `context.http` for FCM API calls
3. ✅ Use FCM Server Key instead of OAuth tokens
4. ✅ Zero external dependencies = faster, more reliable

**Result:** Your trigger will work perfectly in MongoDB Atlas! 🎉

