# Pocket Organizer

A complete cross-platform Flutter app for document management and expense tracking.

## Features

### 📁 Smart Document Manager

- Auto-categorize documents using OCR and AI
- Organize in smart folders (Warranty, Prescription, Receipts, etc.)
- Search by tags, text, or date
- Cloud sync with Firebase

### 💰 Expense Tracker

- Manual expense entry
- Auto-extract from receipts using OCR
- Category-wise analysis with charts
- Daily/Weekly/Monthly summaries

### 🔐 Security

- Biometric authentication (fingerprint/Face ID)
- Local data encryption
- Secure cloud backup

### 🔔 Smart Notifications

- Warranty expiry alerts
- Expense goal reminders

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Firebase Setup

1. Create a Firebase project at https://console.firebase.google.com
2. Add Android and iOS apps to your Firebase project
3. Download configuration files:
   - `google-services.json` → `android/app/`
   - `GoogleService-Info.plist` → `ios/Runner/`
4. Enable Firebase Auth, Firestore, and Storage

### 3. Google ML Kit Setup

- No additional setup needed - uses on-device text recognition

### 4. OpenAI Vision (Optional)

- Add your API key to `.env` file:
  ```
  OPENAI_API_KEY=your_key_here
  ```

### 5. Run Code Generation

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 6. Run App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── core/                     # Core utilities
│   ├── theme/               # App theme
│   ├── constants/           # Constants
│   └── utils/               # Utilities
├── data/
│   ├── models/              # Data models
│   ├── repositories/        # Data repositories
│   └── services/            # Services (OCR, AI, etc.)
├── providers/               # Riverpod providers
├── screens/                 # UI screens
│   ├── auth/               # Authentication
│   ├── home/               # Dashboard
│   ├── folders/            # Folder management
│   ├── documents/          # Document views
│   ├── expenses/           # Expense tracker
│   └── settings/           # Settings
└── widgets/                # Reusable widgets
```

## Tech Stack

- **Framework**: Flutter 3.0+
- **State Management**: Riverpod
- **Local DB**: Hive (encrypted)
- **Cloud**: Firebase (Auth, Firestore, Storage)
- **OCR**: Google ML Kit
- **AI**: OpenAI Vision API (optional)
- **Charts**: fl_chart
- **Security**: local_auth, flutter_secure_storage

## License

MIT License
