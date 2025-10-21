# 🚀 Migrate to FCM V1 API - Complete Guide

## ✅ Why V1 API is Better:

- ✅ Modern and officially supported
- ✅ Won't be deprecated (Legacy API ends June 2024)
- ✅ Better security with OAuth 2.0
- ✅ More features and control

---

## 📋 What You Need:

1. **Service Account JSON file** from Firebase
2. **Firebase Project ID**
3. Update MongoDB function to use V1 API

---

## Step 1: Get Service Account JSON

### **1.1 Download Service Account File**

1. Go to: https://console.firebase.google.com/
2. Select your project
3. Click **⚙️ Settings** → **Project Settings**
4. Go to **"Service accounts"** tab
5. Click **"Generate new private key"** button
6. Click **"Generate key"**
7. A JSON file will download (e.g., `pocket-organizer-firebase-adminsdk-xxxxx.json`)

**Keep this file safe!** It contains sensitive credentials.

---

### **1.2 Get Your Project ID**

In the same Service Accounts page, you'll see:

```
Admin SDK configuration snippet:
{
  "projectId": "pocket-organizer-12345",  ← Copy this!
  ...
}
```

**Copy your Project ID** (e.g., `pocket-organizer-12345`)

---

## Step 2: Add Secrets to MongoDB Atlas

### **2.1 Add Service Account Private Key**

1. Open the **Service Account JSON file** you downloaded
2. Find the `"private_key"` field (looks like):
   ```json
   "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBg...\n-----END PRIVATE KEY-----\n"
   ```
3. **Copy the ENTIRE value** (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)

4. Go to **MongoDB Atlas** → **App Services** → Your app
5. Left sidebar → **Values**
6. Click **"Create New Value"**
7. Fill in:
   - **Name**: `firebase_private_key`
   - **Type**: `Secret` ⚠️
   - **Value**: Paste the private key
8. Click **"Save"**

### **2.2 Add Service Account Email**

1. In the Service Account JSON, find:
   ```json
   "client_email": "firebase-adminsdk-xxxxx@pocket-organizer-12345.iam.gserviceaccount.com"
   ```
2. **Copy that email**

3. In MongoDB Atlas → **Values**
4. Click **"Create New Value"**
5. Fill in:
   - **Name**: `firebase_client_email`
   - **Type**: `Secret` ⚠️
   - **Value**: Paste the email
6. Click **"Save"**

### **2.3 Add Firebase Project ID**

1. In MongoDB Atlas → **Values**
2. Click **"Create New Value"**
3. Fill in:
   - **Name**: `firebase_project_id`
   - **Type**: `Secret` ⚠️
   - **Value**: Your project ID (e.g., `pocket-organizer-12345`)
4. Click **"Save"**

5. Click **"Review Draft & Deploy"**
6. Click **"Deploy"**

---

## Step 3: Generate Access Token

### **Option A: Using gcloud CLI** ⭐ **RECOMMENDED**

1. **Install gcloud CLI** (if not installed):

   - Download from: https://cloud.google.com/sdk/docs/install
   - Or use: `curl https://sdk.cloud.google.com | bash`

2. **Authenticate with Service Account**:

   ```bash
   gcloud auth activate-service-account --key-file=path/to/your-service-account.json
   ```

3. **Generate Access Token**:

   ```bash
   gcloud auth print-access-token
   ```

4. **Copy the token** (it's very long, starts with `ya29.`)

5. **Add to MongoDB Atlas**:
   - MongoDB Atlas → App Services → Values
   - Click "Create New Value"
   - Name: `fcm_access_token`
   - Type: `Secret`
   - Value: Paste the token
   - Save and Deploy

⚠️ **Important**: This token expires in 1 hour! For testing, this is fine. For production, see Option B below.

---

### **Option B: Using Node.js Script** (Alternative)

Create a file `generate-fcm-token.js`:

```javascript
const { google } = require("googleapis");

async function getAccessToken() {
  const key = require("./your-service-account.json");

  const jwtClient = new google.auth.JWT(
    key.client_email,
    null,
    key.private_key,
    ["https://www.googleapis.com/auth/firebase.messaging"],
    null
  );

  const tokens = await jwtClient.authorize();
  console.log("Access Token:", tokens.access_token);
}

getAccessToken();
```

Run:

```bash
npm install googleapis
node generate-fcm-token.js
```

---

## Step 4: Update MongoDB Function

### **Choose Your Version:**

#### **Version 1: Simple (Manual Token Refresh)** ⭐ **Start Here**

Use: `/mongodb_functions/checkBudgetAndSendAlert_V1_SIMPLE.js`

**Pros:**

- ✅ Easy to set up
- ✅ Works immediately

**Cons:**

- ⚠️ Token expires after 1 hour
- ⚠️ Need to regenerate manually

**Best for:** Testing and development

---

#### **Version 2: Advanced (Auto Token Generation)**

Use: `/mongodb_functions/checkBudgetAndSendAlert_V1_API.js`

**Pros:**

- ✅ Auto-generates tokens
- ✅ No manual refresh needed

**Cons:**

- ⚠️ More complex setup
- ⚠️ May not work due to MongoDB Atlas crypto limitations

**Best for:** Production (if it works with your MongoDB version)

---

### **Upload Function to MongoDB Atlas:**

1. Go to **MongoDB Atlas** → **App Services** → Your app
2. Left sidebar → **Functions**
3. Click on `checkBudgetAndSendAlert` (or create new)
4. **Delete all existing code**
5. **Copy code** from `checkBudgetAndSendAlert_V1_SIMPLE.js`
6. **Paste** into function editor
7. Click **"Save"**
8. Click **"Review Draft & Deploy"**
9. Click **"Deploy"**

---

## Step 5: Test It!

1. **Open your app**
2. **Add an expense** that crosses budget threshold
3. **Check MongoDB Atlas Logs**:
   - App Services → Logs
   - Look for "🔔 BUDGET ALERT TRIGGER - V1 API"

### **Expected Success Logs:**

```
🔔 BUDGET ALERT TRIGGER - V1 API
✅ Checking budget for user: xxx
📊 Alert threshold: 90%
✅ FCM token found: dXj9...
📊 Checking daily budget...
   Budget: 1000, Spent: 950, Threshold: 900
   Should alert: true
   📤 Sending FCM notification...
🚀 Sending FCM V1 notification...
   Response status: 200
   ✅ FCM notification sent successfully!
   ✅ Alert sent and saved
✅ Budget check completed
```

---

## 🔄 Token Refresh (For Production)

### **Automated Token Refresh Options:**

#### **Option 1: GitHub Actions** (Recommended)

Create `.github/workflows/refresh-fcm-token.yml`:

```yaml
name: Refresh FCM Token

on:
  schedule:
    - cron: "0 * * * *" # Every hour
  workflow_dispatch: # Manual trigger

jobs:
  refresh:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v0
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}

      - name: Get Access Token
        run: |
          TOKEN=$(gcloud auth print-access-token)
          echo "TOKEN=$TOKEN" >> $GITHUB_ENV

      - name: Update MongoDB Atlas
        run: |
          # Use MongoDB Atlas Admin API to update the value
          curl -X PUT \
            -H "Content-Type: application/json" \
            -u "${{ secrets.MONGODB_PUBLIC_KEY }}:${{ secrets.MONGODB_PRIVATE_KEY }}" \
            "https://realm.mongodb.com/api/admin/v3.0/groups/${{secrets.MONGODB_GROUP_ID}}/apps/${{secrets.MONGODB_APP_ID}}/values/fcm_access_token" \
            -d '{"name":"fcm_access_token","value":"'$TOKEN'"}'
```

---

#### **Option 2: Cron Job on Server**

Create `refresh-token.sh`:

```bash
#!/bin/bash

# Authenticate
gcloud auth activate-service-account --key-file=/path/to/service-account.json

# Get token
TOKEN=$(gcloud auth print-access-token)

# Update MongoDB Atlas (use Atlas Admin API)
curl -X PUT \
  -H "Content-Type: application/json" \
  -u "PUBLIC_KEY:PRIVATE_KEY" \
  "https://realm.mongodb.com/api/admin/v3.0/groups/GROUP_ID/apps/APP_ID/values/fcm_access_token" \
  -d "{\"name\":\"fcm_access_token\",\"value\":\"$TOKEN\"}"
```

Add to crontab:

```bash
crontab -e
# Add this line (runs every 30 minutes):
*/30 * * * * /path/to/refresh-token.sh
```

---

#### **Option 3: Cloud Function** (Best for Production)

Deploy a Cloud Function that refreshes the token automatically. See full guide in the documentation.

---

## 📊 Comparison: Legacy vs V1 API

| Feature            | Legacy API       | V1 API            |
| ------------------ | ---------------- | ----------------- |
| **Server Key**     | ✅ Never expires | ❌ Not used       |
| **Access Token**   | ❌ Not needed    | ⚠️ Expires in 1h  |
| **Setup**          | ✅ Simple        | ⚠️ More complex   |
| **Security**       | ⚠️ Less secure   | ✅ OAuth 2.0      |
| **Future Support** | ❌ Deprecated    | ✅ Supported      |
| **Auto Refresh**   | ✅ Not needed    | ⚠️ Must implement |

---

## 🎯 My Recommendation:

**For Quick Testing**: Use V1 Simple + Manual Token Refresh  
**For Production**: Set up GitHub Actions for auto-refresh

---

## ❓ Need Help?

If you run into issues:

1. Check MongoDB Atlas Logs for error messages
2. Verify Project ID is correct
3. Ensure access token hasn't expired
4. Test token with: `curl -H "Authorization: Bearer YOUR_TOKEN" https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send`

---

## ✅ Summary:

1. ✅ Downloaded service account JSON
2. ✅ Got Project ID from Firebase Console
3. ✅ Generated access token with gcloud
4. ✅ Added values to MongoDB Atlas:
   - `firebase_project_id`
   - `fcm_access_token`
5. ✅ Uploaded V1 function to MongoDB
6. ✅ Ready to test!

Now add an expense and check the logs! 🚀
