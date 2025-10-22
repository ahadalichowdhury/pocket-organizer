/**
 * MongoDB Trigger: Check Expiring Documents (Warranty Reminders)
 * 
 * Runs daily at 9:00 AM to check for documents with expiry dates
 * Sends notifications based on user's reminder preferences
 * 
 * Schedule: Daily at 9:00 AM (cron: "0 9 * * *")
 */

exports = async function() {
  console.log("🔍 ==========================================");
  console.log("🔍 Checking for expiring documents...");
  console.log("🔍 Timestamp:", new Date().toISOString());
  console.log("🔍 ==========================================");
  
  const mongodb = context.services.get("mongodb-atlas");
  const db = mongodb.db("pocket_organizer");
  const documentsCol = db.collection("documents");
  const usersCol = db.collection("users");
  const userSettingsCol = db.collection("user_settings");
  
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  console.log("📅 Today's date:", today.toISOString().split('T')[0]);
  
  try {
    // Get all users with FCM tokens
    const users = await usersCol.find({
      fcmToken: { $exists: true, $ne: null }
    }).toArray();
    
    console.log(`👥 Found ${users.length} users with FCM tokens`);
    
    let totalNotifications = 0;
    let totalUsersNotified = 0;
    
    for (const user of users) {
      console.log(`\n👤 ==========================================`);
      console.log(`👤 Processing user: ${user.userId}`);
      console.log(`👤 Email: ${user.email}`);
      
      // Get user's warranty reminder settings from MongoDB
      const userSettings = await userSettingsCol.findOne({ userId: user.userId });
      
      // Use user's preferences or defaults
      const warrantyRemindersEnabled = userSettings?.warrantyRemindersEnabled ?? false;
      const reminderDays = userSettings?.warrantyReminderDays ?? [30, 7, 1];
      
      console.log(`⚙️ Warranty reminders enabled: ${warrantyRemindersEnabled}`);
      console.log(`⚙️ Reminder days: [${reminderDays.join(', ')}]`);
      
      // Skip if user has disabled warranty reminders
      if (!warrantyRemindersEnabled) {
        console.log(`   ⏭️ Warranty reminders disabled for this user, skipping`);
        continue;
      }
      
      // Get all documents with expiry dates for this user
      const documents = await documentsCol.find({
        userId: user.userId,
        expiryDate: { $exists: true, $ne: null }
      }).toArray();
      
      console.log(`📄 Found ${documents.length} documents with expiry dates`);
      
      if (documents.length === 0) {
        console.log(`   ℹ️ No documents with expiry dates, skipping`);
        continue;
      }
      
      const notificationsToSend = [];
      
      for (const doc of documents) {
        try {
          const expiryDate = new Date(doc.expiryDate);
          expiryDate.setHours(0, 0, 0, 0);
          
          const diffTime = expiryDate.getTime() - today.getTime();
          const daysUntilExpiry = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
          
          console.log(`  📄 ${doc.title}: ${daysUntilExpiry} days until expiry`);
          
          // Skip expired documents (negative days)
          if (daysUntilExpiry < 0) {
            console.log(`     ❌ Already expired, skipping`);
            continue;
          }
          
          // Check if today matches any of the reminder days
          for (const reminderDay of reminderDays) {
            if (daysUntilExpiry === reminderDay) {
              // Check if we haven't already sent this specific reminder
              const remindersSent = doc.remindersSent || [];
              const expiryDateStr = expiryDate.toISOString().split('T')[0];
              const reminderKey = `${reminderDay}d_${expiryDateStr}`;
              
              if (!remindersSent.includes(reminderKey)) {
                console.log(`     ⏰ Triggering ${reminderDay}-day reminder`);
                
                notificationsToSend.push({
                  documentId: doc._id,
                  documentName: doc.title,
                  daysUntilExpiry: daysUntilExpiry,
                  expiryDate: doc.expiryDate,
                  cloudImageUrl: doc.cloudImageUrl,
                  reminderKey: reminderKey
                });
                
                // Mark this reminder as sent
                await documentsCol.updateOne(
                  { _id: doc._id },
                  { 
                    $push: { remindersSent: reminderKey },
                    $set: { lastReminderSent: new Date() }
                  }
                );
              } else {
                console.log(`     ✅ Already sent ${reminderDay}-day reminder`);
              }
            }
          }
        } catch (docError) {
          console.log(`     ❌ Error processing document: ${docError.message}`);
        }
      }
      
      // Send notifications if any found
      if (notificationsToSend.length > 0) {
        console.log(`\n📬 Sending ${notificationsToSend.length} notifications to user: ${user.email}`);
        
        try {
          // Send FCM notifications (one per document)
          for (const notification of notificationsToSend) {
            await sendFCMNotification(user.fcmToken, notification);
          }
          
          // TODO: Send grouped email digest
          // await sendEmailDigest(user.email, notificationsToSend);
          
          totalNotifications += notificationsToSend.length;
          totalUsersNotified++;
          
          console.log(`✅ Successfully sent ${notificationsToSend.length} notifications`);
        } catch (notifError) {
          console.log(`❌ Error sending notifications: ${notifError.message}`);
        }
      } else {
        console.log(`   ℹ️ No notifications to send today`);
      }
    }
    
    console.log(`\n🎉 ==========================================`);
    console.log(`🎉 Expiring documents check completed!`);
    console.log(`🎉 Total users notified: ${totalUsersNotified}`);
    console.log(`🎉 Total notifications sent: ${totalNotifications}`);
    console.log(`🎉 ==========================================`);
    
    return {
      success: true,
      usersProcessed: users.length,
      usersNotified: totalUsersNotified,
      notificationsSent: totalNotifications
    };
    
  } catch (error) {
    console.log(`❌ ==========================================`);
    console.log(`❌ Error in expiring documents check: ${error.message}`);
    console.log(`❌ Stack trace: ${error.stack}`);
    console.log(`❌ ==========================================`);
    
    return {
      success: false,
      error: error.message
    };
  }
};

/**
 * Helper: Send FCM Push Notification
 */
async function sendFCMNotification(fcmToken, notification) {
  const fcm = context.values.get("fcm_access_token");
  
  // Determine urgency color
  let urgency = "🟢";
  if (notification.daysUntilExpiry <= 1) urgency = "🔴";
  else if (notification.daysUntilExpiry <= 7) urgency = "🟠";
  else if (notification.daysUntilExpiry <= 14) urgency = "🟡";
  
  const message = {
    message: {
      token: fcmToken,
      notification: {
        title: `${urgency} ${notification.documentName} Expiring Soon`,
        body: `This document expires in ${notification.daysUntilExpiry} day${notification.daysUntilExpiry !== 1 ? 's' : ''}`,
      },
      data: {
        type: "warranty_expiry",
        documentId: notification.documentId.toString(),
        documentName: notification.documentName,
        daysUntilExpiry: notification.daysUntilExpiry.toString(),
        expiryDate: notification.expiryDate,
        urgency: urgency
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "warranty_reminders",
          defaultSound: true,
          defaultVibrateTimings: true
        }
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1
          }
        }
      }
    }
  };
  
  const response = await context.http.post({
    url: `https://fcm.googleapis.com/v1/projects/pocket-organizer-55a27/messages:send`,
    headers: {
      'Authorization': [`Bearer ${fcm}`],
      'Content-Type': ['application/json']
    },
    body: JSON.stringify(message)
  });
  
  if (response.statusCode === 200) {
    console.log(`  📱 FCM sent for: ${notification.documentName}`);
  } else {
    console.log(`  ❌ FCM failed for: ${notification.documentName} (Status: ${response.statusCode})`);
    console.log(`     Response: ${response.body.text()}`);
  }
}

/**
 * Helper: Send Email Digest (Grouped)
 * TODO: Implement email digest functionality
 */
async function sendEmailDigest(userEmail, notifications) {
  // TODO: Implement email sending via SendGrid or similar service
  console.log(`  📧 Email digest (${notifications.length} items) - Not implemented yet`);
}

