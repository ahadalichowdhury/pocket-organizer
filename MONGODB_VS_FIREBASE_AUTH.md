# 🔄 MongoDB Authentication vs Firebase Auth

## 📊 Current Architecture:

```
┌─────────────────┐
│  Firebase Auth  │ ← User Login/Registration
└────────┬────────┘
         │ Provides userId
         ↓
┌─────────────────┐
│    MongoDB      │ ← Data Storage (expenses, docs, folders)
│                 │   Query by: { userId: firebase_uid }
└─────────────────┘

┌─────────────────┐
│      FCM        │ ← Push Notifications
└─────────────────┘
```

---

## 🆕 Proposed: MongoDB-Only Authentication

```
┌─────────────────┐
│    MongoDB      │ ← User Login/Registration + Data Storage
│                 │   Collections:
│                 │   - users (email, password_hash, etc.)
│                 │   - expenses
│                 │   - documents
│                 │   - folders
└─────────────────┘

┌─────────────────┐
│      FCM        │ ← Still works! (only needs Firebase project)
└─────────────────┘
```

---

## ✅ Advantages:

### 1. **Simpler Architecture**

- Single database for everything
- No dependency on Firebase Auth
- Easier to manage

### 2. **More Control**

- Full control over user data
- Custom authentication logic
- Can add custom fields easily

### 3. **Cost Efficiency**

- Firebase Auth is free (but limited features)
- MongoDB free tier: 512MB storage
- Everything in one place

### 4. **FCM Still Works!**

- You only need a Firebase **project** for FCM
- Firebase Auth is **optional**
- FCM uses Server Key, not Auth tokens

### 5. **User Document Automatically Created**

- When user registers → user document is created immediately
- No separate "create user profile" step needed
- FCM token saved with user document

---

## ⚠️ What Needs to Change:

### **1. Password Security** 🔒

Currently, your `LocalAuthService` stores **plain text passwords** (line 35):

```dart
'password': password, // In production, hash this!
```

With MongoDB auth, you MUST use **bcrypt**:

```dart
import 'package:bcrypt/bcrypt.dart';

// Signup
final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
await usersCollection.insertOne({
  'email': email,
  'password': hashedPassword,  // ✅ Hashed
  'createdAt': DateTime.now(),
});

// Login
final user = await usersCollection.findOne({'email': email});
if (BCrypt.checkpw(password, user['password'])) {
  // ✅ Valid password
}
```

### **2. Session Management** 🎫

**Option A: JWT Tokens (Recommended)**

```dart
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// After successful login
final jwt = JWT({
  'userId': user['_id'],
  'email': user['email'],
  'exp': DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch,
});

final token = jwt.sign(SecretKey('your-secret-key'));
// Save token locally, send with API requests
```

**Option B: Session IDs**

```dart
// Create session
final sessionId = Uuid().v4();
await sessionsCollection.insertOne({
  'sessionId': sessionId,
  'userId': user['_id'],
  'createdAt': DateTime.now(),
  'expiresAt': DateTime.now().add(Duration(days: 7)),
});
```

### **3. Email Verification** 📧

```dart
// Send verification code
final verificationCode = Random().nextInt(999999).toString().padLeft(6, '0');
await usersCollection.updateOne(
  {'_id': userId},
  {'\$set': {'verificationCode': verificationCode, 'isVerified': false}},
);
// Send email with code (need SMTP service)
```

### **4. Password Reset** 🔑

```dart
// Generate reset token
final resetToken = Uuid().v4();
await usersCollection.updateOne(
  {'email': email},
  {
    '\$set': {
      'resetToken': resetToken,
      'resetTokenExpiry': DateTime.now().add(Duration(hours: 1)),
    }
  },
);
// Send email with reset link
```

### **5. Auth State Management** 🔄

**Current (Firebase):**

```dart
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
```

**New (MongoDB):**

```dart
final authStateProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier() : super(null) {
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final token = await SecureStorage.read('auth_token');
    if (token != null && _isTokenValid(token)) {
      final userId = _getUserIdFromToken(token);
      state = User(id: userId);
    }
  }

  Future<void> login(String email, String password) async {
    // MongoDB login logic
    final user = await MongoDBAuth.login(email, password);
    state = user;
  }

  void logout() {
    SecureStorage.delete('auth_token');
    state = null;
  }
}
```

---

## 📝 Code Changes Needed:

### **Files to Modify:**

1. **`lib/data/services/auth_service.dart`**

   - Replace Firebase Auth with MongoDB queries
   - Add password hashing (bcrypt)
   - Add JWT token generation

2. **`lib/data/services/mongodb_auth_service.dart`** _(NEW)_

   - Create MongoDB authentication service
   - Login, signup, verify email, reset password

3. **`lib/providers/app_providers.dart`**

   - Change `authStateProvider` from StreamProvider to StateNotifierProvider
   - Update auth logic

4. **`lib/screens/auth/login_screen.dart`**

   - Minimal changes (backend calls different service)

5. **`lib/screens/auth/signup_screen.dart`**

   - Add email verification step (optional)

6. **`pubspec.yaml`**
   - Add: `bcrypt: ^1.1.3`
   - Add: `dart_jsonwebtoken: ^2.12.0`

---

## 🎯 MongoDB Users Collection Structure:

```json
{
  "_id": "auto-generated-mongodb-id",
  "email": "user@example.com",
  "password": "$2b$10$...", // ✅ Bcrypt hashed
  "displayName": "John Doe",
  "createdAt": "2025-10-21T...",
  "isVerified": true,
  "fcmToken": "dXj9abc...",
  "fcmTokenUpdatedAt": "2025-10-21T...",
  "platform": "android",
  "lastLogin": "2025-10-21T...",
  "profilePicture": "https://...",

  // Optional fields
  "phoneNumber": "+1234567890",
  "verificationCode": "123456",
  "resetToken": "uuid-token",
  "resetTokenExpiry": "2025-10-21T..."
}
```

---

## 🚀 Migration Path:

### **Option 1: Switch Completely to MongoDB Auth**

**Steps:**

1. Create `MongoDBAuthService`
2. Update all auth references
3. Add password hashing
4. Implement JWT tokens
5. Test thoroughly

**Pros:**

- Single system
- Full control

**Cons:**

- More work
- Need to handle security yourself

---

### **Option 2: Hybrid (Current Firebase + MongoDB data)**

**Steps:**

1. Keep Firebase Auth for login/signup
2. Create user document in MongoDB **on signup**
3. Sync FCM token to MongoDB user document

**Pros:**

- Less work
- Firebase handles security
- OAuth (Google, Apple) support

**Cons:**

- Dependency on two systems

---

### **Option 3: Keep Firebase Auth, Fix User Document Issue** ⭐ **RECOMMENDED**

**Steps:**

1. Keep current setup (Firebase Auth)
2. Create `UserSyncService` to create user document in MongoDB
3. Call it on signup and login

**Pros:**

- Minimal changes
- Best of both worlds
- Firebase security + MongoDB data

**Cons:**

- Slight dependency on Firebase

---

## ✅ My Recommendation:

**Keep Firebase Auth + Fix MongoDB User Document Creation**

### Why?

1. **Security**: Firebase Auth is battle-tested and secure
2. **Features**: Email verification, password reset, OAuth built-in
3. **Easy**: Minimal code changes
4. **Scalable**: Can handle millions of users
5. **FCM Integration**: Works seamlessly with Firebase project

### What to Do:

I'll create a `UserSyncService` that:

- Creates user document in MongoDB on signup
- Updates user profile on login
- Syncs FCM token automatically

This fixes your current issue (no user document) while keeping the robust Firebase Auth system!

---

## 📊 Comparison Table:

| Feature                   | Firebase Auth | MongoDB Auth       | Hybrid (Recommended) |
| ------------------------- | ------------- | ------------------ | -------------------- |
| **Password Security**     | ✅ Built-in   | ⚠️ Must implement  | ✅ Built-in          |
| **Email Verification**    | ✅ Built-in   | ⚠️ Must implement  | ✅ Built-in          |
| **Password Reset**        | ✅ Built-in   | ⚠️ Must implement  | ✅ Built-in          |
| **OAuth (Google, Apple)** | ✅ Built-in   | ❌ Not possible    | ✅ Built-in          |
| **User Data in MongoDB**  | ⚠️ Needs sync | ✅ Automatic       | ✅ Easy sync         |
| **FCM Token Storage**     | ⚠️ Separate   | ✅ Same document   | ✅ Same document     |
| **Development Time**      | ✅ Fast       | ⚠️ Slow (security) | ✅ Fast              |
| **Maintenance**           | ✅ Easy       | ⚠️ Complex         | ✅ Easy              |
| **Cost**                  | ✅ Free tier  | ✅ Free tier       | ✅ Free tier         |

---

## 🎯 Next Steps (Recommended):

Let me create a `UserSyncService` that fixes your current issue while keeping Firebase Auth!

Should I:

1. ✅ **Create UserSyncService** (keeps Firebase Auth, fixes MongoDB user issue)
2. Create full MongoDB Auth (replaces Firebase Auth)
3. Something else?

**Option 1 is quickest and solves your problem!** 🚀
