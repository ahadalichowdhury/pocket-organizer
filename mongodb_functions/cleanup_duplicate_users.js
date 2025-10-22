// MongoDB Script to Remove Duplicate Users
// Run this in MongoDB Compass or MongoDB Shell

// ==========================================
// CLEAN UP DUPLICATE USERS
// ==========================================
// This script removes duplicate user documents,
// keeping only the one with the most recent FCM token

db.users.aggregate([
  {
    // Group by userId to find duplicates
    $group: {
      _id: "$userId",
      count: { $sum: 1 },
      docs: { $push: "$$ROOT" }
    }
  },
  {
    // Filter only duplicates (count > 1)
    $match: {
      count: { $gt: 1 }
    }
  }
]).forEach(function(group) {
  print("==========================================");
  print("Found " + group.count + " duplicates for userId: " + group._id);
  
  // Sort docs by fcmTokenUpdatedAt (most recent first)
  group.docs.sort(function(a, b) {
    var dateA = a.fcmTokenUpdatedAt || a.createdAt || "";
    var dateB = b.fcmTokenUpdatedAt || b.createdAt || "";
    return dateB.localeCompare(dateA); // Descending order
  });
  
  // Keep the first one (most recent FCM token)
  var keepDoc = group.docs[0];
  print("Keeping document with _id: " + keepDoc._id);
  print("  FCM Token: " + (keepDoc.fcmToken ? "Present" : "NULL"));
  print("  FCM Token Updated: " + (keepDoc.fcmTokenUpdatedAt || "NULL"));
  
  // Delete all others
  for (var i = 1; i < group.docs.length; i++) {
    var deleteDoc = group.docs[i];
    print("Deleting document with _id: " + deleteDoc._id);
    print("  FCM Token: " + (deleteDoc.fcmToken ? "Present" : "NULL"));
    print("  FCM Token Updated: " + (deleteDoc.fcmTokenUpdatedAt || "NULL"));
    
    db.users.deleteOne({ _id: deleteDoc._id });
  }
  
  print("✅ Cleaned up duplicates for userId: " + group._id);
  print("==========================================");
});

print("\n✅ Duplicate cleanup complete!");
print("Verifying no duplicates remain...\n");

// Verify: Check if any duplicates still exist
var duplicateCount = db.users.aggregate([
  {
    $group: {
      _id: "$userId",
      count: { $sum: 1 }
    }
  },
  {
    $match: {
      count: { $gt: 1 }
    }
  },
  {
    $count: "duplicateUsers"
  }
]).toArray();

if (duplicateCount.length === 0) {
  print("✅ SUCCESS: No duplicate users found!");
} else {
  print("⚠️ WARNING: Still found " + duplicateCount[0].duplicateUsers + " duplicate userId(s)");
}

// Show final user count
print("\nTotal unique users: " + db.users.distinct("userId").length);
print("Total user documents: " + db.users.countDocuments({}));

