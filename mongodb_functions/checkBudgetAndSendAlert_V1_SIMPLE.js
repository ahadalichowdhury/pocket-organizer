/**
 * MongoDB Realm Function: Budget Alert Checker (FCM V1 API - Simplified)
 * 
 * This version uses FCM V1 API with a pre-generated access token
 * 
 * IMPORTANT: Access tokens expire after 1 hour!
 * For production, you'll need to regenerate tokens regularly or use a different approach.
 * 
 * REQUIRED MONGODB ATLAS VALUES (as Secrets):
 * - fcm_access_token: OAuth 2.0 access token (regenerate hourly)
 * - firebase_project_id: Your Firebase project ID
 * 
 * HOW TO GENERATE ACCESS TOKEN:
 * Run this command on your computer (requires gcloud CLI):
 * 
 * gcloud auth activate-service-account --key-file=path/to/service-account.json
 * gcloud auth print-access-token
 * 
 * Copy the token and add it to MongoDB Atlas Values as "fcm_access_token"
 * 
 * For automated token refresh, see FCM_V1_API_MIGRATION.md
 */

exports = async function(changeEvent) {
  const mongodb = context.services.get("mongodb-atlas");
  const db = mongodb.db("pocket_organizer");
  
  console.log("=====================================");
  console.log("🔔 BUDGET ALERT TRIGGER - V1 API");
  console.log("=====================================");
  
  const expense = changeEvent.fullDocument;
  if (!expense || !expense.userId) {
    console.log("⚠️ No userId in expense, skipping");
    return;
  }
  
  const userId = expense.userId;
  console.log(`✅ Checking budget for user: ${userId}`);
  
  try {
    // Get user settings
    const userSettings = await db.collection("user_settings").findOne({ userId });
    if (!userSettings) {
      console.log("⚠️ No settings found for user");
      return;
    }
    
    // Check if notifications are enabled
    if (userSettings.notificationsEnabled === false) {
      console.log("🔕 Notifications disabled for user, skipping");
      return;
    }
    
    const alertThreshold = userSettings.alertThreshold || 80;
    console.log(`📊 Alert threshold: ${alertThreshold}%`);
    
    // Get user FCM token
    const userDoc = await db.collection("users").findOne({ userId });
    if (!userDoc || !userDoc.fcmToken) {
      console.log("⚠️ No FCM token found for user");
      return;
    }
    
    console.log(`✅ FCM token found: ${userDoc.fcmToken.substring(0, 20)}...`);
    const fcmToken = userDoc.fcmToken;
    
    // Check each budget period
    const budgetChecks = [
      { budget: userSettings.dailyBudget, period: 'daily', key: 'daily_budget' },
      { budget: userSettings.weeklyBudget, period: 'weekly', key: 'weekly_budget' },
      { budget: userSettings.monthlyBudget, period: 'monthly', key: 'monthly_budget' }
    ];
    
    for (const check of budgetChecks) {
      if (check.budget && check.budget > 0) {
        await checkAndAlert({
          userId,
          fcmToken,
          budget: check.budget,
          alertThreshold,
          period: check.period,
          budgetKey: check.key,
          db
        });
      }
    }
    
    console.log("✅ Budget check completed");
    
  } catch (error) {
    console.error("❌ Error in trigger:", error);
    console.error("Stack:", error.stack);
  }
};

async function checkAndAlert({ userId, fcmToken, budget, alertThreshold, period, budgetKey, db }) {
  try {
    console.log(`\n📊 Checking ${period} budget...`);
    
    // Calculate date range based on USER'S CURRENT TIME (not trigger time)
    // We need to be flexible with timezones since expenses are stored with full timestamps
    const now = new Date();
    let startDate, endDate;
    
    if (period === 'daily') {
      // For daily budget, we want expenses from "today" in the user's timezone
      // But since expenses have full timestamps, we need to check the date part only
      // Solution: Query last 48 hours to catch timezone differences
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
      endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2);
    } else if (period === 'weekly') {
      const dayOfWeek = now.getDay();
      const diff = now.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1);
      startDate = new Date(now.getFullYear(), now.getMonth(), diff - 1);
      startDate.setHours(0, 0, 0, 0);
      endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 9); // 7 days + 2 day buffer
    } else if (period === 'monthly') {
      startDate = new Date(now.getFullYear(), now.getMonth(), 0); // Last day of previous month
      endDate = new Date(now.getFullYear(), now.getMonth() + 1, 2); // 2 days into next month
    }
    
    // Get expenses for period (with timezone buffer)
    console.log(`   Date range (with buffer): ${startDate.toISOString()} to ${endDate.toISOString()}`);
    
    const allExpenses = await db.collection("expenses")
      .find({
        userId: userId,
        date: { $gte: startDate.toISOString(), $lt: endDate.toISOString() }
      })
      .toArray();
    
    console.log(`   Found ${allExpenses.length} expenses in extended period`);
    
    // Now filter expenses to match the actual period by parsing dates
    const expenses = allExpenses.filter(exp => {
      const expDate = new Date(exp.date);
      const expYear = expDate.getUTCFullYear();
      const expMonth = expDate.getUTCMonth();
      const expDay = expDate.getUTCDate();
      
      const nowYear = now.getUTCFullYear();
      const nowMonth = now.getUTCMonth();
      const nowDay = now.getUTCDate();
      
      if (period === 'daily') {
        // Check if expense is from today OR tomorrow (to handle worldwide timezones)
        // User in GMT+12 thinks it's tomorrow when server (UTC) thinks it's today
        // User in GMT-12 thinks it's yesterday when server (UTC) thinks it's today
        // Solution: Accept expenses from today AND tomorrow
        const isToday = expYear === nowYear && expMonth === nowMonth && expDay === nowDay;
        const isTomorrow = expYear === nowYear && expMonth === nowMonth && expDay === (nowDay + 1);
        return isToday || isTomorrow;
      } else if (period === 'weekly') {
        // Check if expense is in current week
        const dayOfWeek = now.getUTCDay();
        const weekStart = new Date(Date.UTC(nowYear, nowMonth, nowDay - dayOfWeek + (dayOfWeek === 0 ? -6 : 1)));
        const weekEnd = new Date(weekStart);
        weekEnd.setUTCDate(weekEnd.getUTCDate() + 7);
        return expDate >= weekStart && expDate < weekEnd;
      } else if (period === 'monthly') {
        // Check if expense is from current month
        return expYear === nowYear && expMonth === nowMonth;
      }
      return false;
    });
    
    console.log(`   Filtered to ${expenses.length} expenses in actual ${period} period`);
    if (expenses.length > 0) {
      console.log(`   Sample expense: date=${expenses[0].date}, amount=${expenses[0].amount}`);
    }
    
    const totalSpent = expenses.reduce((sum, exp) => sum + (exp.amount || 0), 0);
    const thresholdAmount = budget * (alertThreshold / 100);
    const shouldAlert = totalSpent >= thresholdAmount && totalSpent < budget;
    
    console.log(`   Budget: ${budget}, Spent: ${totalSpent}, Threshold: ${thresholdAmount}`);
    console.log(`   Should alert: ${shouldAlert}`);
    
    if (shouldAlert) {
      // Check if already alerted
      const lastAlert = await db.collection("budget_alerts").findOne({
        userId: userId,
        budgetKey: budgetKey,
        amount: totalSpent
      });
      
      if (lastAlert) {
        console.log(`   ⏭️ Already alerted for this amount`);
        return;
      }
      
      console.log(`   📤 Sending FCM notification...`);
      
      // Send FCM V1 notification
      try {
        await sendFCMNotificationV1({
          fcmToken,
          title: `${capitalize(period)} Budget Alert`,
          body: `You've spent $${totalSpent.toFixed(2)} of $${budget.toFixed(2)} (${alertThreshold}% threshold reached)`,
          data: {
            type: 'budget_alert',
            period: period,
            spent: totalSpent.toString(),
            budget: budget.toString()
          }
        });
        
        // Save alert record
        await db.collection("budget_alerts").insertOne({
          userId: userId,
          budgetKey: budgetKey,
          amount: totalSpent,
          alertedAt: new Date(),
          period: period
        });
        
        console.log(`   ✅ Alert sent and saved`);
        
      } catch (fcmError) {
        console.error(`   ❌ FCM SEND FAILED:`, fcmError);
        console.error(`   Error message: ${fcmError.message}`);
        console.error(`   Error stack: ${fcmError.stack}`);
        throw fcmError; // Re-throw to be caught by parent
      }
    }
    
  } catch (error) {
    console.error(`   ❌ Error in ${period} check:`, error);
  }
}

async function sendFCMNotificationV1({ fcmToken, title, body, data }) {
  try {
    console.log("\n🚀 Sending FCM V1 notification...");
    
    // Get access token from MongoDB Atlas Secret
    console.log("   🔑 Fetching fcm_access_token...");
    const accessToken = await context.values.get("fcm_access_token");
    console.log(`   Access token exists: ${!!accessToken}`);
    if (!accessToken) {
      console.error("   ❌ FCM access token is null/undefined!");
      throw new Error("FCM access token not configured. Run: gcloud auth print-access-token");
    }
    
    // Get project ID
    console.log("   🔑 Fetching firebase_project_id...");
    
    // DEBUG: Try to list all available values
    try {
      const allValueNames = await context.values.names();
      console.log("   📋 All available values:", allValueNames);
    } catch (e) {
      console.log("   ⚠️ Could not list values:", e.message);
    }
    
    const projectId = await context.values.get("firebase_project_id");
    console.log(`   Project ID exists: ${!!projectId}, value: ${projectId}`);
    if (!projectId) {
      console.error("   ❌ Firebase project ID is null/undefined!");
      throw new Error("Firebase project ID not configured");
    }
    
    // FCM V1 endpoint
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    
    // Build message
    const message = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: body
        },
        data: data || {},
        android: {
          priority: 'high',
          notification: {
            channel_id: 'budget_alerts',
            sound: 'default'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      }
    };
    
    console.log(`   Endpoint: ${fcmEndpoint}`);
    console.log(`   Token: ${fcmToken.substring(0, 20)}...`);
    console.log(`   Access token: ${accessToken.substring(0, 20)}...`);
    
    // Send request
    const response = await context.http.post({
      url: fcmEndpoint,
      headers: {
        'Authorization': [`Bearer ${accessToken}`],
        'Content-Type': ['application/json']
      },
      body: JSON.stringify(message)
    });
    
    console.log(`   Response status: ${response.statusCode}`);
    const responseBody = response.body.text();
    console.log(`   Response: ${responseBody}`);
    
    if (response.statusCode === 200) {
      console.log("   ✅ FCM notification sent successfully!");
      return true;
    } else {
      console.error(`   ❌ FCM error: ${responseBody}`);
      
      // Check for token expiration
      if (responseBody.includes("invalid_grant") || responseBody.includes("Token expired")) {
        console.error("   ⚠️ Access token expired! Generate new token with: gcloud auth print-access-token");
      }
      
      throw new Error(`FCM failed: ${responseBody}`);
    }
    
  } catch (error) {
    console.error("   ❌ Error sending FCM:", error);
    throw error;
  }
}

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

