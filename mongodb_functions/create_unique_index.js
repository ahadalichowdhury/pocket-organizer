// MongoDB Script to Create Unique Index on userId
// Run this in MongoDB Compass or MongoDB Shell
// This GUARANTEES no duplicate users can ever be created

// ==========================================
// CREATE UNIQUE INDEX ON userId
// ==========================================

print("Creating unique index on 'userId' field in 'users' collection...");

// Create unique index
db.users.createIndex(
  { userId: 1 },
  { 
    unique: true,
    name: "unique_userId"
  }
);

print("✅ Unique index created successfully!");
print("\nThis ensures:");
print("  - No duplicate userId values can exist");
print("  - MongoDB will reject any attempt to insert duplicate userId");
print("  - Even concurrent operations are safe");

// Verify the index was created
print("\nVerifying index...");
var indexes = db.users.getIndexes();
var uniqueIndex = indexes.find(function(idx) {
  return idx.name === "unique_userId";
});

if (uniqueIndex) {
  print("✅ Index verified:");
  print("  Name: " + uniqueIndex.name);
  print("  Keys: " + JSON.stringify(uniqueIndex.key));
  print("  Unique: " + uniqueIndex.unique);
} else {
  print("❌ Index not found!");
}

print("\n==========================================");
print("IMPORTANT: Before creating this index,");
print("make sure you've cleaned up any existing");
print("duplicates using cleanup_duplicate_users.js");
print("==========================================");

