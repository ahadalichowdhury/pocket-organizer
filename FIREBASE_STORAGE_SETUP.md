# Firebase Storage Setup Guide

## Issue: `object-not-found` Error

The error `[firebase_storage/object-not-found] No object exists at the desired reference` occurs when:

1. Firebase Storage is not enabled in your Firebase project
2. Firebase Storage security rules are blocking uploads
3. The storage bucket is not properly configured

## Fix: Enable Firebase Storage & Update Rules

### Step 1: Enable Firebase Storage

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`pocket-organizer` or similar)
3. Click on **Storage** in the left sidebar
4. If not enabled, click **Get Started**
5. Choose a location for your storage bucket
6. Click **Done**

### Step 2: Update Storage Security Rules

Firebase Storage needs proper security rules to allow authenticated users to upload/download their documents.

1. In Firebase Console → **Storage** → **Rules** tab
2. Replace the existing rules with the following:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Allow users to upload/read/delete their own documents
    match /users/{userId}/documents/{documentId}/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Allow users to access their entire folder
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

3. Click **Publish**

### Step 3: Verify Configuration

After updating the rules:

1. Restart your app
2. Try adding a new document with an image
3. Check the debug console for upload progress

### Expected Console Output (Success):

```
📤 [CloudStorage] Uploading image: 1760957027124.jpg
   Local path: /data/user/0/com.example.pocket_organizer/app_flutter/documents/1760957027124.jpg
   File exists: true
   File size: 245678 bytes
   Storage path: users/RGGkiwwvdxZjk6Ofovzds36aRI62/documents/d54df6e0-95d5-44a9-81f9-f6f6a4d8293d/1760957027124.jpg
   Upload progress: 50%
   Upload progress: 100%
✅ [CloudStorage] Upload successful
   Download URL: https://firebasestorage.googleapis.com/v0/b/...
```

## Alternative: Disable Cloud Storage (Local Only)

If you don't want to use Firebase Storage, the app will continue working with **local storage only**:

- Images are saved locally on the device
- `cloudImageUrl` will be `null` in MongoDB
- Images won't sync across devices
- App will still work perfectly for single-device use

The app is designed to gracefully handle both scenarios!

## Security Note

The rules above ensure:

- ✅ Users can only access their own files
- ✅ Authentication is required for all operations
- ✅ Each user's data is isolated by their `userId`
- ✅ No anonymous access allowed

## Troubleshooting

### Error: `unauthorized` or `permission-denied`

- **Cause**: Security rules are too restrictive
- **Fix**: Apply the rules above

### Error: `object-not-found`

- **Cause**: Firebase Storage not enabled OR wrong bucket
- **Fix**: Enable Storage in Firebase Console

### Error: `quota-exceeded`

- **Cause**: Free tier storage limit reached (5GB)
- **Fix**: Upgrade to Blaze plan or clean up old files

## Storage Usage

Monitor your storage usage in:

- Firebase Console → Storage → Usage tab
- App Settings → Data & Storage → Storage Info

---

**After configuring Firebase Storage, your documents will have:**

- ✅ `localImagePath`: Local device path
- ✅ `cloudImageUrl`: Firebase Storage URL (for sync across devices)
- ✅ Both stored in MongoDB for complete backup
