# User Data Isolation Fix

## Problem

The app was showing data from previous users who logged in on the same device. This happened because:

1. **No userId field in local models**: The Hive database models (`ExpenseModel`, `DocumentModel`, `FolderModel`) don't have a `userId` field
2. **Data persisted across logins**: When a user logged out, their local data remained in Hive
3. **No filtering on login**: When a new user logged in, they could see all locally stored data from previous users

## Solution

### 1. Clear Local Data on Logout ✅

Updated `lib/screens/settings/settings_screen.dart`:

```dart
ElevatedButton(
  onPressed: () async {
    // Clear all local data before signing out
    await HiveService.clearAllData();

    // Sign out from Firebase
    await ref.read(authServiceProvider).signOut();

    if (context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  },
  child: const Text('Log Out'),
),
```

### 2. Clear Local Data on Login ✅

Updated `lib/screens/auth/login_screen.dart`:

```dart
if (result['success']) {
  print('🔐 [Login] Login successful');

  // Clear all local data before syncing (prevents data leak between users)
  print('🔐 [Login] Clearing local data...');
  try {
    await HiveService.clearAllData();
    print('🔐 [Login] ✅ Local data cleared');
  } catch (e) {
    print('🔐 [Login] ⚠️ Failed to clear local data: $e');
  }

  // Then sync user-specific data from MongoDB...
  await expensesNotifier.performFullSync();
  await documentsNotifier.performFullSync();
  await foldersNotifier.performFullSync();

  // Navigate to home...
}
```

### 3. MongoDB Duplicate Folder Removal Script ✅

Created `scripts/remove_duplicate_folders.dart` to clean up duplicate folders in MongoDB.

**How to run**:

```bash
dart run scripts/remove_duplicate_folders.dart
```

This script:

- Finds all folders with the same `userId` + `name` combination
- Keeps the most recently updated folder
- Deletes all older duplicates
- Provides detailed output of operations

## How It Works Now

### User Login Flow:

1. User enters credentials
2. Firebase authentication succeeds
3. **All local Hive data is cleared** (ensures no data from previous user)
4. User-specific data is downloaded from MongoDB (filtered by `userId` in sync services)
5. User sees only their own data

### User Logout Flow:

1. User clicks "Log Out"
2. **All local Hive data is cleared** (prevents data leak to next user)
3. Firebase sign out
4. Navigate to login screen

### Data Synchronization:

- MongoDB sync services already filter by `userId`:
  - `ExpenseSyncService`: Uses `where.eq('userId', user.uid)`
  - `DocumentSyncService`: Uses `where.eq('userId', user.uid)`
  - `FolderSyncService`: Uses `where.eq('userId', user.uid)`
- Only the current user's data is synced down

## Why This Works

1. **Local Data is Session-Based**: By clearing Hive on login/logout, local data becomes session-based rather than persistent across users
2. **MongoDB is User-Isolated**: All MongoDB queries filter by `userId`, ensuring only the current user's data is retrieved
3. **No Cross-Contamination**: Even if one user's data somehow remained local, clearing on login ensures the next user starts fresh

## Testing

To verify the fix:

1. **Test 1 - New Login**:

   - Login as User A
   - Create some expenses/documents
   - Logout
   - Login as User B
   - **Expected**: User B sees NO data from User A

2. **Test 2 - Forced Logout**:

   - Login as User A
   - Close app without logging out
   - Login as User B
   - **Expected**: User B sees NO data from User A (cleared on login)

3. **Test 3 - Return to Original User**:
   - Login as User A
   - Create expenses/documents
   - Logout
   - Login as User B
   - Login back as User A
   - **Expected**: User A sees their original data (synced from MongoDB)

## MongoDB Duplicate Cleanup

If you have duplicate folders in MongoDB:

1. **Backup your database first!**

   ```bash
   mongodump --uri="your-connection-string" --out=backup
   ```

2. **Run the cleanup script**:

   ```bash
   dart run scripts/remove_duplicate_folders.dart
   ```

3. **Verify the results**: Check the script output for summary of removed duplicates

## Future Improvements (Optional)

If you want to add multi-user support on the same device in the future:

1. Add `userId` field to all models (`ExpenseModel`, `DocumentModel`, `FolderModel`)
2. Update Hive type adapters (increment typeIds)
3. Filter all repository methods by `currentUser.uid`
4. Only clear data for the logging-out user (not all data)

However, the current solution is simpler and works perfectly for the typical use case where one device = one user at a time.

## Related Files

- `lib/screens/auth/login_screen.dart` - Clears data on login
- `lib/screens/settings/settings_screen.dart` - Clears data on logout
- `lib/data/services/hive_service.dart` - `clearAllData()` method
- `lib/data/services/expense_sync_service.dart` - MongoDB sync with userId filter
- `lib/data/services/document_sync_service.dart` - MongoDB sync with userId filter
- `lib/data/services/folder_sync_service.dart` - MongoDB sync with userId filter
- `scripts/remove_duplicate_folders.dart` - MongoDB cleanup script
