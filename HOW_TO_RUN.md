# 🚀 How to Run & Test Pocket Organizer

## Step-by-Step Setup & Testing Guide

---

## 📋 Prerequisites

Make sure you have installed:

- ✅ Flutter SDK (3.0+): https://flutter.dev/docs/get-started/install
- ✅ Xcode (for iOS) or Android Studio (for Android)
- ✅ Git
- ✅ A code editor (VS Code, Android Studio, or IntelliJ)

Check your Flutter installation:

```bash
flutter doctor
```

---

## 🔧 Step 1: Install Dependencies

```bash
cd /Users/s.m.ahadalichowdhury/Downloads/project/pocket-organizer

# Install all Flutter packages
flutter pub get
```

Expected output: "Got dependencies!"

---

## 🏗️ Step 2: Generate Hive Adapters (CRITICAL!)

The app uses Hive for local storage. You MUST generate the type adapters:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This creates:

- `folder_model.g.dart`
- `document_model.g.dart`
- `expense_model.g.dart`

**What you'll see:**

```
[INFO] Generating build script...
[INFO] Building new asset graph...
[INFO] Succeeded after Xs
```

---

## 🔥 Step 3: Setup Firebase

### Option A: Quick Test (Skip Firebase for Now)

You can test the app without Firebase by modifying `lib/main.dart`:

```dart
// Comment out Firebase initialization temporarily
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // COMMENT THIS OUT FOR QUICK TESTING:
  // try {
  //   await Firebase.initializeApp();
  // } catch (e) {
  //   print('Firebase init failed: $e');
  // }

  await HiveService.init();
  runApp(const ProviderScope(child: MyApp()));
}
```

**Note:** Without Firebase, authentication won't work, but you can still test the UI.

### Option B: Full Firebase Setup (Recommended)

1. **Install FlutterFire CLI:**

```bash
dart pub global activate flutterfire_cli
```

2. **Configure Firebase:**

```bash
flutterfire configure
```

Follow the prompts:

- Login with Google account
- Select or create Firebase project
- Choose platforms (iOS, Android)
- It will generate `firebase_options.dart`

3. **Enable Firebase Services:**
   - Go to https://console.firebase.google.com
   - Select your project
   - Enable **Authentication** → Email/Password
   - Enable **Cloud Firestore** (Start in test mode)
   - Enable **Storage** (Start in test mode)

---

## 📱 Step 4: Add Platform Permissions

### For Android:

1. Edit `android/app/src/main/AndroidManifest.xml`:

Add these permissions inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

2. Update `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Change from flutter.minSdkVersion
        targetSdkVersion 33
    }
}
```

### For iOS:

Edit `ios/Runner/Info.plist` and add before `</dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to capture documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select images</string>
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID for secure authentication</string>
```

Also update `ios/Podfile`:

```ruby
platform :ios, '12.0'
```

Then run:

```bash
cd ios
pod install
cd ..
```

---

## ▶️ Step 5: Run the App!

### Check Available Devices:

```bash
flutter devices
```

### Run on Connected Device/Emulator:

```bash
# Run on any available device
flutter run

# Or specify a device
flutter run -d <device-id>

# Run in debug mode (default)
flutter run --debug

# Run in release mode (faster, for testing performance)
flutter run --release
```

### For Android Emulator:

```bash
# List emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator-id>

# Then run
flutter run
```

### For iOS Simulator:

```bash
# Open simulator
open -a Simulator

# Then run
flutter run
```

---

## 🧪 Step 6: Testing the App

### Manual Testing Flow:

#### 1. **First Launch - Onboarding**

- ✅ See onboarding screens
- ✅ Swipe through 4 pages
- ✅ Click "Get Started"

#### 2. **Authentication** (if Firebase enabled)

- ✅ Try signing up with email/password
  - Email: `test@example.com`
  - Password: `test123`
- ✅ Verify form validation
- ✅ After signup, you should reach the home screen
- ✅ Default folders should be auto-created

#### 3. **Test Document Capture**

- ✅ Click the "Capture" floating button
- ✅ Grant camera permission when prompted
- ✅ Take a photo or select from gallery
- ✅ Crop the image
- ✅ Wait for OCR processing
- ✅ Check if document type is auto-detected
- ✅ Edit title, select folder
- ✅ Click "Save"

#### 4. **Test Folders**

- ✅ Navigate to "Folders" tab
- ✅ See default folders (Warranty, Prescription, etc.)
- ✅ Create a new folder (+ button)
- ✅ Try renaming a folder
- ✅ Try deleting an empty folder

#### 5. **Test Expenses**

- ✅ Navigate to "Expenses" tab
- ✅ Click + to add expense
- ✅ Enter amount, category, payment method
- ✅ Save expense
- ✅ Check if it appears in the list
- ✅ View pie chart
- ✅ Switch between Day/Week/Month views

#### 6. **Test Search**

- ✅ Click search icon
- ✅ Type keywords
- ✅ Check if documents and expenses appear
- ✅ Filter by type

#### 7. **Test Settings**

- ✅ Navigate to "Settings" tab
- ✅ Toggle dark mode (app should update)
- ✅ Try enabling biometric lock (on physical device)
- ✅ View storage info
- ✅ Try logout

---

## 🔧 Troubleshooting Common Issues

### Issue 1: Build Fails with Hive Errors

```
Error: The getter 'xxx' isn't defined for the class 'FolderModel'
```

**Solution:**

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue 2: Firebase Not Initialized

```
[ERROR] Firebase initialization failed
```

**Solution:**

- Run `flutterfire configure` again
- Or comment out Firebase code in `main.dart` for testing

### Issue 3: Camera Permission Denied

**Solution:**

- Check platform permissions in AndroidManifest.xml / Info.plist
- Uninstall app and reinstall to reset permissions

### Issue 4: OCR Not Working

**Solution:**

- OCR works best on physical devices
- Ensure good lighting and clear text
- Try with a printed document (not handwritten)

### Issue 5: Biometric Not Working

**Solution:**

- Biometric only works on physical devices
- Enable biometric in device settings first
- Grant app permission

### Issue 6: Hot Reload Not Working

**Solution:**

```bash
# Stop and restart
flutter run
```

---

## 🧪 Testing Without Physical Device

### Test on Emulator/Simulator:

**What Works:**

- ✅ UI and navigation
- ✅ Authentication (with Firebase)
- ✅ Folder management
- ✅ Expense tracking
- ✅ Search
- ✅ Theme switching
- ✅ Gallery image selection

**What Doesn't Work on Emulator:**

- ❌ Camera capture (no camera on emulator)
- ❌ Biometric authentication
- ❌ Some OCR features may be limited

**Workaround:**

- Use gallery instead of camera
- Use sample images for testing

---

## 📊 Performance Testing

```bash
# Run in profile mode to check performance
flutter run --profile

# Check app size
flutter build apk --analyze-size

# Run performance overlay
# Add this in the app (MaterialApp):
showPerformanceOverlay: true,
```

---

## 🐛 Debug Mode Tips

### Enable Verbose Logging:

In `lib/main.dart`, add:

```dart
void main() async {
  // ...
  debugPrint('App starting...');
  // ...
}
```

### Check Hive Data:

Add this to check stored data:

```dart
// In any screen
final folders = HiveService.getAllFolders();
print('Folders: ${folders.length}');
```

### Debug OCR:

```dart
// In capture_document_screen.dart
print('OCR Text: $_ocrText');
print('Classification: $_suggestedType');
print('Confidence: $_confidence');
```

---

## 📱 Build for Testing

### Android APK:

```bash
flutter build apk --debug
# APK location: build/app/outputs/flutter-apk/app-debug.apk
```

### iOS (requires Mac):

```bash
flutter build ios --debug
```

---

## ✅ Quick Test Checklist

- [ ] App launches without crashes
- [ ] Onboarding screens work
- [ ] Can create account (if Firebase enabled)
- [ ] Can capture/select image
- [ ] OCR extracts text from image
- [ ] Document saves to folder
- [ ] Can create expense manually
- [ ] Charts display correctly
- [ ] Search finds documents
- [ ] Dark mode toggles correctly
- [ ] Can create custom folder
- [ ] Navigation works smoothly
- [ ] No console errors

---

## 🎯 Next Steps After Testing

1. **Customize Theme** - Edit colors in `app_theme.dart`
2. **Add Your Branding** - Replace icons and splash screen
3. **Configure Firebase** - Set up production rules
4. **Add OpenAI Key** - For AI classification (optional)
5. **Test on Real Device** - For camera and biometric
6. **Build Release Version** - `flutter build apk --release`

---

## 📞 Need Help?

If something doesn't work:

1. Check console output for errors
2. Run `flutter doctor` to check setup
3. Read error messages carefully
4. Check the documentation files
5. Make sure all steps above were followed

---

**You're ready to test! 🚀**

Start with: `flutter pub get` → `flutter pub run build_runner build` → `flutter run`
