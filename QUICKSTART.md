# 🎯 Pocket Organizer - Quick Start

## Complete Flutter App for Document Management & Expense Tracking

### ✅ What's Built

- **Authentication**: Login, Signup, Onboarding
- **Document Management**: Camera capture, OCR, Auto-classification, Smart folders
- **Expense Tracking**: Manual entry, Auto-extract from receipts, Charts & analytics
- **Search**: Universal search for documents and expenses
- **Security**: Biometric auth, Encrypted storage
- **UI**: Material 3, Dark mode, Responsive design

---

## 🚀 Setup (5 Steps)

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Generate Hive Adapters

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Configure Firebase

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure project
flutterfire configure
```

### 4. Add Platform Permissions

**iOS** (`ios/Runner/Info.plist`):

```xml
<key>NSCameraUsageDescription</key>
<string>Capture documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Select images</string>
<key>NSFaceIDUsageDescription</key>
<string>Secure authentication</string>
```

**Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

Update `android/app/build.gradle`:

```gradle
minSdkVersion 21
```

### 5. Run

```bash
flutter run
```

---

## 📁 Project Structure

```
lib/
├── main.dart                    # Entry point with Firebase init
├── core/
│   ├── constants/              # Document types, categories
│   ├── router/                 # Navigation
│   └── theme/                  # Material 3 theme
├── data/
│   ├── models/                 # Hive models
│   ├── repositories/           # Business logic
│   └── services/               # Auth, OCR, AI, Database
├── providers/                  # Riverpod state management
├── screens/                    # All UI screens
└── widgets/                    # Reusable components
```

---

## 🔧 Firebase Setup

1. Go to https://console.firebase.google.com
2. Create project
3. Add iOS & Android apps
4. Download config files
5. Enable:
   - Authentication (Email/Password)
   - Cloud Firestore
   - Storage

---

## 🎨 Features

### Document Management

- 📷 Camera capture with crop
- 🔍 OCR text extraction (Google ML Kit)
- 🤖 Auto-classification (AI-powered)
- 📁 Smart folder organization
- 🏷️ Tags, notes, expiry dates
- 🔗 Link to expenses

### Expense Tracking

- 💰 Manual entry or auto-extract from receipts
- 📊 Category breakdown (pie charts)
- 📅 Daily/Weekly/Monthly summaries
- 💳 Payment method tracking
- 🔍 Search and filter

### Security

- 🔐 Biometric unlock (Face ID/Touch ID)
- 🔒 Encrypted local storage (Hive)
- 🛡️ Firebase secure auth

---

## 🐛 Troubleshooting

**Firebase Error**: Run `flutterfire configure`  
**Hive Error**: Run `flutter pub run build_runner build --delete-conflicting-outputs`  
**Permission Denied**: Check platform-specific setup above  
**Biometric Not Working**: Test on physical device (not emulator)

---

## 📦 Tech Stack

- **Framework**: Flutter 3.0+
- **State**: Riverpod
- **Database**: Hive (offline-first)
- **Auth**: Firebase
- **OCR**: Google ML Kit
- **Charts**: fl_chart

---

## 🎯 Next Steps

1. ✅ Run setup commands above
2. ✅ Test on device
3. ✅ Customize theme/colors
4. ✅ Add your Firebase project
5. ✅ Build and deploy!

---

**Need help?** Check SETUP.md and DEVELOPMENT.md for detailed guides.

**License**: MIT
