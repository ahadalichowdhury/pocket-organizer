# Database Maintenance Scripts

This directory contains utility scripts for maintaining and fixing the MongoDB database.

## Available Scripts

### 1. Remove Duplicate Folders (`remove_duplicate_folders.dart`)

**Purpose**: Removes duplicate folder entries from MongoDB that have the same `userId` and `name`.

**What it does**:

- Connects to MongoDB using credentials from `.env`
- Finds all folders with the same `userId` + `name` combination
- Keeps the most recently updated folder
- Deletes all older duplicates

**How to run**:

```bash
# From the project root directory
dart run scripts/remove_duplicate_folders.dart
```

**Prerequisites**:

- Make sure your `.env` file is configured with valid MongoDB credentials
- Ensure you have `mongo_dart` and `flutter_dotenv` packages installed

**Safety**:

- The script only deletes true duplicates (same userId + name)
- It always keeps the most recently updated version
- It provides detailed output of what it's doing
- **Recommendation**: Back up your MongoDB database before running this script

**Example Output**:

```
🔧 MongoDB Duplicate Folder Removal Script
==========================================

✅ Loaded .env file
🔌 Connecting to MongoDB...
✅ Connected to MongoDB

📂 Fetching all folders...
   Found 42 folders

🔍 Searching for duplicates...

📋 Found 3 duplicates for user: user123, folder: "Receipts"
   ✓ Keeping: 60d5ec9af0e3a3c7d8b9e1a2 (updated: 2025-10-20 14:30:00.000)
   ✗ Deleted: 60d5ec5bf0e3a3c7d8b9e1a1 (updated: 2025-10-18 10:15:00.000)
   ✗ Deleted: 60d5ec2ef0e3a3c7d8b9e1a0 (updated: 2025-10-15 08:00:00.000)

📊 Summary
==========================================
Total folders: 42
Duplicate groups found: 1
Duplicates removed: 2
✅ Cleanup complete!

🔌 Disconnected from MongoDB
```

## Important Notes

1. **Backup First**: Always create a backup of your MongoDB database before running any maintenance scripts.

2. **Test Environment**: If possible, test the script on a copy of your database first.

3. **User Data**: These scripts work on production data. Use with caution.

4. **Logs**: The scripts provide detailed logs of all operations for auditing purposes.

## Adding New Scripts

When creating new maintenance scripts:

1. Add the script to this `scripts/` directory
2. Update this README with:
   - Script name and purpose
   - What it does
   - How to run it
   - Any prerequisites
   - Expected output format
3. Follow the same logging pattern (using emojis for clarity)
4. Always include safety checks and confirmations where appropriate
