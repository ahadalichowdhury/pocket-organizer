# 📋 Warranty Reminders Feature - Implementation Guide

## 🎯 Overview

This document provides a complete guide for the Warranty Reminders feature implementation.

---

## ✅ **COMPLETED - Phase 1 (Core Backend & Settings)**

### 1. Document Model Updates ✅

**File:** `lib/data/models/document_model.dart`

Added tracking fields:

```dart
@HiveField(15)
List<String>? remindersSent; // e.g., ["30d_2024-10-25", "7d_2024-10-25"]

@HiveField(16)
DateTime? lastReminderSent;
```

### 2. Settings Page UI ✅

**File:** `lib/screens/settings/settings_screen.dart`

- Multi-select warranty reminder days (30, 14, 7, 1 days)
- Enable/disable toggle
- Color-coded urgency indicators
- Real-time settings sync to MongoDB

### 3. MongoDB Trigger ✅

**File:** `mongodb_functions/checkExpiringDocuments.js`

- Runs daily at 9:00 AM
- Checks all documents with expiry dates
- Sends FCM notifications
- Tracks which reminders were sent
- Prevents duplicate notifications

---

## 🚧 **TODO - Remaining Implementation**

### 4. FCM Notification Handling (Flutter Side)

**File to create/modify:** `lib/data/services/fcm_service.dart`

Add handler for warranty expiry notifications:

```dart
// In _handleNotification method, add new case:
case 'warranty_expiry':
  // Navigate to documents screen
  // Or show expiring documents view
  break;
```

### 5. Home Page - Expiring Soon Card

**File to modify:** `lib/screens/home/home_screen.dart`

Add card showing:

```dart
┌─────────────────────────────────────┐
│ ⚠️ Expiring Soon                    │
│                                     │
│ 3 documents expiring in next 30 days│
│ • Most urgent: iPhone warranty (2d) │
│                                     │
│           [View All] →              │
└─────────────────────────────────────┘
```

### 6. Filtered Expiring Documents View

**File to create:** `lib/screens/documents/expiring_documents_screen.dart`

Features:

- List of expiring documents
- Status badges (🟢🟡🟠🔴)
- Smart sorting by urgency
- Quick actions (edit expiry, view document)

### 7. Document Edit Menu

**File to modify:** `lib/screens/documents/document_detail_screen.dart`

Add options in 3-dot menu:

- Edit Expiry Date
- Remove Expiry Date
- Set as Warranty

---

## 📱 **MongoDB Atlas Setup Instructions**

### Step 1: Create Scheduled Trigger

1. Go to MongoDB Atlas → Your Cluster → Triggers
2. Click "Add Trigger"
3. Configure:

   - **Trigger Type:** Scheduled
   - **Name:** `CheckExpiringDocuments`
   - **Schedule Type:** Advanced (Cron Expression)
   - **Cron Schedule:** `0 9 * * *` (Daily at 9:00 AM)
   - **Function:** Create new function
   - **Function Name:** `checkExpiringDocuments`

4. Paste the code from `mongodb_functions/checkExpiringDocuments.js`
5. Save and deploy

### Step 2: Verify FCM Access Token

Ensure the `fcm_access_token` value exists in MongoDB Atlas App Services:

- Go to Values → fcm_access_token
- Should be updated every 30 minutes by GitHub Action

### Step 3: Test the Trigger

1. Click "Run" in the trigger interface
2. Check logs to verify it works
3. Test with a document expiring soon

---

## 🧪 **Testing Checklist**

### Settings Page:

- [ ] Toggle warranty reminders on/off
- [ ] Select multiple reminder days
- [ ] Settings persist after app restart
- [ ] Settings sync to MongoDB

### MongoDB Trigger:

- [ ] Trigger runs at 9:00 AM daily
- [ ] Correctly calculates days until expiry
- [ ] Sends FCM notifications
- [ ] Doesn't send duplicate notifications
- [ ] Handles multiple documents per user

### Notifications:

- [ ] Push notification appears
- [ ] Notification shows correct document name
- [ ] Notification shows correct days until expiry
- [ ] Clicking notification opens app

### Home Page:

- [ ] Shows count of expiring documents
- [ ] Shows most urgent document
- [ ] Clicking opens filtered view

### Document Management:

- [ ] Can set expiry date on new documents
- [ ] Can edit expiry date
- [ ] Can remove expiry date
- [ ] Expiry dates sync to MongoDB

---

## 🎨 **Status Badge Color Coding**

```
🟢 Valid       - More than 30 days until expiry
🟡 Upcoming    - 15-30 days until expiry
🟠 Soon        - 2-14 days until expiry
🔴 Critical    - 0-1 days until expiry (expires today/tomorrow)
⚫ Expired     - Past expiry date
```

---

## 📊 **Data Flow**

```
1. User sets expiry date on document
   ↓
2. Document saved to Hive + MongoDB
   ↓
3. MongoDB trigger runs daily at 9:00 AM
   ↓
4. Trigger checks: daysUntilExpiry == reminderDays?
   ↓
5. If match: Send FCM + Mark as sent
   ↓
6. Flutter receives FCM notification
   ↓
7. User clicks → Opens app to expiring documents
```

---

## 🚀 **Deployment Steps**

### 1. Flutter App:

```bash
# Regenerate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# Test locally
flutter run

# Build APK
flutter build apk --split-per-abi
```

### 2. MongoDB:

- Deploy the trigger in Atlas
- Verify it runs successfully
- Check logs for any errors

### 3. GitHub Action:

- Already set up for FCM token refresh every 30 minutes

---

## 💡 **Future Enhancements (Phase 3)**

- [ ] Email digest of expiring documents
- [ ] OCR to auto-detect expiry dates from images
- [ ] Recurring warranties (auto-renew annually)
- [ ] Statistics dashboard (total warranty value, expiry trends)
- [ ] Widget showing next expiring item
- [ ] Snooze reminder option
- [ ] Export expiring documents report

---

## 📞 **Support & Troubleshooting**

### Issue: Notifications not received

- Check FCM token is set for user in MongoDB
- Verify trigger is running (check logs)
- Ensure `fcm_access_token` is valid

### Issue: Duplicate notifications

- Check `remindersSent` array in document
- Verify trigger logic for duplicate prevention

### Issue: Wrong days count

- Check timezone settings in MongoDB trigger
- Verify date calculation logic

---

## ✅ **Implementation Status**

- [x] Document model updates
- [x] Settings page UI
- [x] MongoDB trigger
- [x] User settings sync
- [ ] FCM notification handling (Flutter)
- [ ] Home page expiring soon card
- [ ] Filtered expiring documents view
- [ ] Document edit menu
- [ ] Status badges implementation
- [ ] Smart sorting

**Estimated remaining time:** 2-3 hours

---

**Created:** October 22, 2024  
**Last Updated:** October 22, 2024  
**Version:** 1.0 (Phase 1 Complete)
