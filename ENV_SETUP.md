# Environment Setup Guide

## 📋 Prerequisites

1. **MongoDB Atlas Account** (Free tier available)

   - Sign up at: https://www.mongodb.com/cloud/atlas
   - Create a new cluster
   - Create a database named `pocket_organizer`
   - Get your connection string

2. **OpenAI API Key** (Optional - for AI features)

   - Sign up at: https://platform.openai.com/
   - Generate an API key from: https://platform.openai.com/api-keys

3. **Email Account for Reports** (Optional - for automated email reports)
   - Gmail, Outlook, or any SMTP-enabled email
   - For Gmail: Enable App Passwords (requires 2FA)
   - Go to: https://myaccount.google.com/apppasswords

## ⚙️ Environment Configuration

### Step 1: Copy the example file

```bash
cp .env.example .env
```

### Step 2: Edit the `.env` file with your credentials

Open `.env` and update these values:

```env
# MongoDB Configuration
MONGODB_CONNECTION_STRING=mongodb+srv://YOUR_USERNAME:YOUR_PASSWORD@YOUR_CLUSTER.mongodb.net/pocket_organizer?retryWrites=true&w=majority
MONGODB_DATABASE_NAME=pocket_organizer

# OpenAI API Key (optional)
OPENAI_API_KEY=sk-proj-YOUR_API_KEY_HERE

# Email Report Configuration (optional - for automated reports)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SENDER_EMAIL=your-email@gmail.com
SENDER_PASSWORD=your-app-password-here
SENDER_NAME=Pocket Organizer

# App Configuration
ENABLE_MONGODB=true
ENABLE_DEBUG_LOGS=false
```

### Step 3: Getting MongoDB Connection String

1. Go to MongoDB Atlas Dashboard
2. Click "Connect" on your cluster
3. Choose "Connect your application"
4. Select "Driver: Node.js" (or any driver)
5. Copy the connection string
6. Replace `<username>` and `<password>` with your database user credentials
7. Replace `<dbname>` with `pocket_organizer`

**Example:**

```
mongodb+srv://myuser:mypassword@cluster0.abc123.mongodb.net/pocket_organizer?retryWrites=true&w=majority
```

## 🔒 Security Notes

**IMPORTANT:**

- ✅ The `.env` file is already in `.gitignore` - never commit it!
- ✅ Never share your API keys or connection strings publicly
- ✅ Use different credentials for development and production
- ✅ Rotate your keys regularly

## 🚀 Running the App

After setting up your `.env` file:

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build APK
flutter build apk --profile --split-per-abi
```

## 🔧 Configuration Options

### MongoDB Settings

- **MONGODB_CONNECTION_STRING**: Your MongoDB Atlas connection string
- **MONGODB_DATABASE_NAME**: Database name (default: `pocket_organizer`)
- **ENABLE_MONGODB**: Set to `true` to enable cloud sync, `false` for local-only mode

### App Settings

- **OPENAI_API_KEY**: Required for AI document classification features
- **ENABLE_DEBUG_LOGS**: Set to `true` for detailed console logs

### Email Report Settings

- **SMTP_HOST**: Your email provider's SMTP server
  - Gmail: `smtp.gmail.com`
  - Outlook: `smtp-mail.outlook.com`
- **SMTP_PORT**: Usually `587` for TLS
- **SENDER_EMAIL**: Your email address
- **SENDER_PASSWORD**: Your email password or App Password (recommended for Gmail)
- **SENDER_NAME**: Display name for sent emails

**Gmail Setup:**

1. Enable 2-Factor Authentication on your Google account
2. Go to https://myaccount.google.com/apppasswords
3. Create a new App Password for "Mail"
4. Use the generated password (16 characters) in SENDER_PASSWORD

## 📱 Features

- **Local Storage**: All data is stored locally using Hive (works offline)
- **Cloud Sync**: Optional MongoDB sync for multi-device support
- **Firebase Auth**: User authentication (email/password)
- **Firebase Messaging**: Push notifications for budget alerts
- **No Firebase Firestore**: We use MongoDB instead (no more 400 errors!)

## ❓ Troubleshooting

### MongoDB not connecting?

- Check your connection string format
- Verify your IP address is whitelisted in MongoDB Atlas
- Make sure your database user has proper permissions
- Set `ENABLE_MONGODB=false` to use local-only mode

### OpenAI API not working?

- Verify your API key is valid
- Check if you have credits in your OpenAI account
- The app will work without OpenAI, just without AI classification

### App won't build?

```bash
flutter clean
flutter pub get
flutter build apk --profile --split-per-abi
```

## 📞 Support

If you encounter any issues, check:

1. All dependencies are installed: `flutter pub get`
2. `.env` file exists and has correct values
3. MongoDB Atlas IP whitelist includes your IP
4. Firebase is configured: `flutterfire configure`
