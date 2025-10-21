# Development Notes

## Code Generation Commands

### Hive Adapters

Generate type adapters for Hive models:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Watch for changes:

```bash
flutter pub run build_runner watch
```

## Firebase Configuration

After running `flutterfire configure`, a file `firebase_options.dart` will be generated. This contains your Firebase configuration.

If you encounter issues:

1. Delete `firebase_options.dart`
2. Run `flutterfire configure` again
3. Select your Firebase project
4. Choose platforms (iOS, Android, Web, etc.)

## Important Notes

### OpenAI Vision API (Optional)

The app includes optional AI-powered document classification using OpenAI Vision API. This feature is not required for basic functionality.

To enable:

1. Get API key from https://platform.openai.com
2. Update the key in `lib/providers/app_providers.dart`

### Google ML Kit

Google ML Kit is used for on-device OCR. No API key required. It works offline.

### Local Storage

All data is stored locally using Hive. Documents are stored as file paths, and images remain on device storage.

### Cloud Sync (Future Feature)

Cloud sync with Firebase Firestore and Storage is prepared but not fully implemented. You can extend the repositories to add cloud sync functionality.

## Folder Structure Explained

```
lib/
├── main.dart                          # App entry, Firebase init, routing
├── core/
│   ├── constants/
│   │   └── app_constants.dart        # Document types, expense categories
│   ├── router/
│   │   └── app_router.dart           # Route definitions
│   └── theme/
│       └── app_theme.dart            # Light & dark themes
├── data/
│   ├── models/                       # Data models with Hive annotations
│   │   ├── folder_model.dart         # Folder entity
│   │   ├── document_model.dart       # Document entity
│   │   └── expense_model.dart        # Expense entity
│   ├── repositories/                 # Business logic layer
│   │   ├── folder_repository.dart    # Folder CRUD operations
│   │   ├── document_repository.dart  # Document CRUD operations
│   │   └── expense_repository.dart   # Expense CRUD & analytics
│   └── services/                     # External services
│       ├── auth_service.dart         # Firebase Auth wrapper
│       ├── hive_service.dart         # Hive database operations
│       ├── ocr_service.dart          # Google ML Kit OCR
│       └── ai_classification_service.dart  # OpenAI Vision (optional)
├── providers/
│   └── app_providers.dart            # Riverpod providers (state management)
├── screens/                          # UI screens
│   ├── auth/
│   │   ├── onboarding_screen.dart    # First-time user onboarding
│   │   ├── login_screen.dart         # Email/password login
│   │   └── signup_screen.dart        # User registration
│   ├── home/
│   │   └── home_screen.dart          # Dashboard with stats
│   ├── folders/
│   │   └── folders_screen.dart       # Folder list & management
│   ├── documents/
│   │   └── capture_document_screen.dart  # Camera capture & OCR
│   ├── expenses/
│   │   └── expenses_screen.dart      # Expense tracking with charts
│   ├── settings/
│   │   └── settings_screen.dart      # App settings
│   └── search/
│       └── search_screen.dart        # Universal search
└── widgets/                          # Reusable components
    ├── folder_card.dart              # Folder grid item
    ├── document_tile.dart            # Document list item
    └── expense_summary_card.dart     # Expense summary widget

```

## State Management Flow

1. **UI Layer** (Screens/Widgets)

   - Consumes providers using `ref.watch()`
   - Triggers actions using `ref.read().notifier`

2. **Provider Layer** (Riverpod)

   - Manages app state
   - Exposes StateNotifiers for mutable state
   - Provides services and repositories

3. **Repository Layer**

   - Handles business logic
   - Coordinates between services
   - Transforms data for UI

4. **Service Layer**
   - Handles external interactions
   - Database operations (Hive)
   - API calls (Firebase, OpenAI)
   - Device features (Camera, Biometric)

## Performance Considerations

- Lazy loading for document lists
- Image compression before storage
- Debounced search queries
- Cached folder/document counts
- IndexedStack for bottom navigation (preserves state)

## Security Best Practices

1. Local data encryption via Hive encrypted boxes
2. Biometric authentication for app access
3. Secure token storage (Firebase Auth handles this)
4. No hardcoded API keys in production
5. Validate user input before database operations

## Testing Strategy

- Unit tests for repositories and services
- Widget tests for reusable components
- Integration tests for critical flows
- Mock Firebase and Hive for testing

## Debugging Tips

### Enable verbose logging:

```dart
// In main.dart
debugPrint('Your debug message');
print('Regular log');
```

### Check Hive data:

```dart
final box = await Hive.openBox('folders');
print(box.values);
```

### Test OCR locally:

```dart
final ocrService = OcrService();
final text = await ocrService.extractTextFromImage('path/to/image.jpg');
print(text);
```

## Common Gotchas

1. **Hive adapters must be registered** before opening boxes
2. **Firebase must be initialized** before any Firebase calls
3. **Platform permissions** must be added for camera/photos
4. **Image cropper** requires platform-specific setup
5. **Biometric auth** only works on physical devices, not emulators
