# Pocket Organizer - Complete Flutter App

## 🎯 Quick Start Guide

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Generate Code (Hive Adapters)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Firebase Setup

#### Option A: Using FlutterFire CLI (Recommended)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure
```

#### Option B: Manual Setup

1. Create a Firebase project at https://console.firebase.google.com
2. Add Android and iOS apps
3. Download configuration files:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/`
4. Enable Firebase Authentication (Email/Password & Phone)
5. Enable Cloud Firestore
6. Enable Firebase Storage

### 4. Platform-Specific Setup

#### iOS Setup

Add permissions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to capture documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select images</string>
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID for secure authentication</string>
```

#### Android Setup

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

Update `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 33
    }
}
```

### 5. Optional: OpenAI Vision API

If you want to use AI document classification:

1. Get API key from https://platform.openai.com
2. Update `lib/providers/app_providers.dart`:

```dart
final aiClassificationServiceProvider = Provider<AiClassificationService>((ref) {
  const apiKey = 'YOUR_OPENAI_API_KEY'; // Replace with your key
  return AiClassificationService(apiKey: apiKey);
});
```

### 6. Run the App

```bash
flutter run
```

---

## 📱 Features

### ✅ Implemented Features

1. **Authentication**

   - Email/Password login and signup
   - Firebase Authentication integration
   - Onboarding flow for new users

2. **Document Management**

   - Camera capture with crop functionality
   - OCR text extraction using Google ML Kit
   - Automatic document classification
   - Smart folder organization
   - Document tagging and notes
   - Expiry date tracking for warranties/prescriptions

3. **Folder System**

   - Auto-created system folders (Warranty, Prescription, Receipt, etc.)
   - Custom folder creation
   - Folder rename and delete
   - Document count tracking

4. **Expense Tracking**

   - Manual expense entry
   - Auto-extract from receipts (OCR)
   - Category-wise breakdown
   - Daily/Weekly/Monthly summaries
   - Visual charts (pie chart for categories)
   - Payment method tracking

5. **Search**

   - Search documents by title, tags, OCR text
   - Search expenses by category, store, notes
   - Filter by type (Documents/Expenses)

6. **Settings**

   - Dark/Light theme toggle
   - Biometric authentication (fingerprint/Face ID)
   - Notifications toggle
   - Data export
   - Cloud sync settings
   - Account management

7. **Security**
   - Local data encryption with Hive
   - Biometric unlock support
   - Secure Firebase authentication

---

## 🏗️ Architecture

### Clean Architecture Pattern

```
lib/
├── main.dart                      # App entry point
├── core/
│   ├── constants/                # App constants
│   ├── router/                   # Navigation routing
│   └── theme/                    # App theme (Material 3)
├── data/
│   ├── models/                   # Data models (Hive)
│   │   ├── folder_model.dart
│   │   ├── document_model.dart
│   │   └── expense_model.dart
│   ├── repositories/             # Data repositories
│   │   ├── folder_repository.dart
│   │   ├── document_repository.dart
│   │   └── expense_repository.dart
│   └── services/                 # Services
│       ├── auth_service.dart
│       ├── hive_service.dart
│       ├── ocr_service.dart
│       └── ai_classification_service.dart
├── providers/                    # Riverpod state management
│   └── app_providers.dart
├── screens/                      # UI screens
│   ├── auth/                    # Authentication screens
│   ├── home/                    # Dashboard
│   ├── folders/                 # Folder management
│   ├── documents/               # Document capture & details
│   ├── expenses/                # Expense tracking
│   ├── settings/                # App settings
│   └── search/                  # Search functionality
└── widgets/                     # Reusable widgets
    ├── folder_card.dart
    ├── document_tile.dart
    └── expense_summary_card.dart
```

### State Management

- **Riverpod** for reactive state management
- Separate providers for auth, folders, documents, expenses
- StateNotifier pattern for mutable state

### Local Database

- **Hive** for offline-first storage
- Type adapters for models
- Encrypted boxes for sensitive data

---

## 🔧 Configuration

### Customization

#### Change App Name

Update `pubspec.yaml`:

```yaml
name: your_app_name
```

#### Change App Theme Colors

Edit `lib/core/theme/app_theme.dart`:

```dart
static const primaryColor = Color(0xFF6366F1); // Your color
```

#### Add Custom Document Types

Edit `lib/core/constants/app_constants.dart`:

```dart
class DocumentType {
  static const String yourType = 'Your Type';
  // Add to allTypes list
}
```

#### Add Custom Expense Categories

Edit `lib/core/constants/app_constants.dart`:

```dart
class ExpenseCategory {
  static const String yourCategory = 'Your Category';
  // Add to allCategories list
}
```

---

## 🧪 Testing

### Run Tests

```bash
flutter test
```

### Run on Device

```bash
# List devices
flutter devices

# Run on specific device
flutter run -d device_id
```

---

## 📦 Building for Production

### Android APK

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

---

## 🐛 Troubleshooting

### Issue: Firebase not initialized

**Solution:** Run `flutterfire configure` and restart the app

### Issue: Hive adapters not generated

**Solution:** Run `flutter pub run build_runner build --delete-conflicting-outputs`

### Issue: Camera permission denied

**Solution:** Check platform-specific permission setup in AndroidManifest.xml and Info.plist

### Issue: Biometric not working

**Solution:** Test on physical device (biometric doesn't work on emulators)

### Issue: OCR not detecting text

**Solution:** Ensure good lighting and image quality, crop document properly

---

## 🎨 UI/UX Guidelines

- **Material 3 Design** with modern components
- **Responsive layouts** for different screen sizes
- **Smooth animations** for navigation and transitions
- **Dark mode support** with theme switching
- **Accessibility** features (semantic labels, contrast ratios)

---

## 🚀 Future Enhancements

- [ ] Cloud backup and sync
- [ ] Document sharing
- [ ] Recurring expenses
- [ ] Budget goals and alerts
- [ ] Multi-language support
- [ ] PDF document support
- [ ] Barcode/QR code scanning
- [ ] Receipt templates
- [ ] Export to PDF/Excel
- [ ] Widgets for home screen
- [ ] Apple Watch / Wear OS support

---

## 📄 License

MIT License - See LICENSE file for details

---

## 👥 Contributing

Contributions are welcome! Please read CONTRIBUTING.md for guidelines.

---

## 📞 Support

For issues and questions:

- Create an issue on GitHub
- Email: support@pocketorganizer.app

---

## ⭐ Show Your Support

If you find this project helpful, please give it a ⭐ on GitHub!
