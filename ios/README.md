# iOS Configuration Notes

## Permissions

Add the following to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to capture documents</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images</string>

<key>NSFaceIDUsageDescription</key>
<string>This app uses Face ID for secure authentication</string>
```

## Minimum iOS Version

Set minimum iOS version to 12.0 in `ios/Podfile`:

```ruby
platform :ios, '12.0'
```
