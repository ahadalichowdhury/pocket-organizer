/**
 * MongoDB Realm Function: Budget Alert Checker
 * 
 * This function is triggered when an expense is synced to MongoDB.
 * It checks if any budget thresholds are crossed and sends FCM notifications.
 * 
 * IMPORTANT: This function DOES NOT use firebase-admin or any external packages
 * It uses MongoDB Atlas context.http for HTTP requests to FCM API
 * 
 * SETUP INSTRUCTIONS:
 * 1. Go to MongoDB Atlas → App Services → Your App
 * 2. Create a new Function called "checkBudgetAndSendAlert"
 * 3. Copy this code into the function
 * 4. ENSURE NO DEPENDENCIES are added (no package.json, no npm packages)
 * 5. Create a Database Trigger:
 *    - Trigger Type: Database
 *    - Name: "ExpenseSyncTrigger"
 *    - Cluster: Your cluster name
 *    - Database: pocket_organizer
 *    - Collection: expenses
 *    - Operation Type: Insert, Update
 *    - Function: checkBudgetAndSendAlert
 * 6. Create a MongoDB Atlas Value/Secret called "fcm_access_token"
 * 7. Save and deploy
 * 
 * NO EXTERNAL PACKAGES REQUIRED - Uses only built-in context APIs
 */

exports = async function(changeEvent) {
  const mongodb = context.services.get("mongodb-atlas");
  const db = mongodb.db("pocket_organizer");
  
  // Get the expense document
  const expense = changeEvent.fullDocument;
  if (!expense || !expense.userId) {
    console.log("No userId in expense, skipping");
    return;
  }
  
  const userId = expense.userId;
  console.log(`📊 Checking budget for user: ${userId}`);
  
  try {
    // Get user's settings (budget limits and alert threshold)
    const userSettings = await db.collection("user_settings").findOne({ userId });
    if (!userSettings) {
      console.log("⚠️ No settings found for user");
      return;
    }
    
    const alertThreshold = userSettings.alertThreshold || 80;
    const currencySymbol = userSettings.currencySymbol || '$';
    const dailyBudget = userSettings.dailyBudget;
    const weeklyBudget = userSettings.weeklyBudget;
    const monthlyBudget = userSettings.monthlyBudget;
    
    console.log(`💰 Currency: ${currencySymbol}, Alert Threshold: ${alertThreshold}%`);
    
    // Get user's FCM token
    const userDoc = await db.collection("users").findOne({ userId });
    if (!userDoc || !userDoc.fcmToken) {
      console.log("⚠️ No FCM token found for user");
      return;
    }
    
    const fcmToken = userDoc.fcmToken;
    console.log(`✅ FCM token found`);
    
    // Check daily budget
    if (dailyBudget && dailyBudget > 0) {
      await checkAndAlert({
        userId,
        fcmToken,
        budget: dailyBudget,
        alertThreshold,
        period: 'daily',
        budgetKey: 'daily_budget',
        db
      });
    }
    
    // Check weekly budget
    if (weeklyBudget && weeklyBudget > 0) {
      await checkAndAlert({
        userId,
        fcmToken,
        budget: weeklyBudget,
        alertThreshold,
        period: 'weekly',
        budgetKey: 'weekly_budget',
        db
      });
    }
    
    // Check monthly budget
    if (monthlyBudget && monthlyBudget > 0) {
      await checkAndAlert({
        userId,
        fcmToken,
        budget: monthlyBudget,
        alertThreshold,
        period: 'monthly',
        budgetKey: 'monthly_budget',
        db
      });
    }
    
  } catch (error) {
    console.error("Error checking budget:", error);
  }
};

async function checkAndAlert({ userId, fcmToken, budget, alertThreshold, period, budgetKey, db }) {
  try {
    // Calculate date range based on period
    const now = new Date();
    let startDate, endDate;
    
    if (period === 'daily') {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 1);
    } else if (period === 'weekly') {
      const dayOfWeek = now.getDay();
      const diff = now.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1); // Monday as start
      startDate = new Date(now.getFullYear(), now.getMonth(), diff);
      startDate.setHours(0, 0, 0, 0);
      endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 7);
    } else if (period === 'monthly') {
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
      endDate = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    }
    
    // Get user settings for currency symbol
    const userSettings = await db.collection("user_settings").findOne({ userId });
    const currencySymbol = userSettings?.currencySymbol || '$';
    
    console.log(`📅 Date range: ${startDate.toISOString()} to ${endDate.toISOString()}`);
    
    // DEBUG: Check what date format is stored in MongoDB
    const sampleExpense = await db.collection("expenses").findOne({ userId: userId });
    if (sampleExpense) {
      console.log(`🔍 Sample expense date type: ${typeof sampleExpense.date}, value: ${sampleExpense.date}`);
    }
    
    // Convert date range to ISO strings for comparison (dates are stored as strings in MongoDB)
    const startDateStr = startDate.toISOString();
    const endDateStr = endDate.toISOString();
    
    // Get expenses for the period (compare as strings)
    const expenses = await db.collection("expenses")
      .find({
        userId: userId,
        date: { $gte: startDateStr, $lt: endDateStr }
      })
      .toArray();
    
    console.log(`📝 Found ${expenses.length} expenses in ${period} period`);
    if (expenses.length > 0) {
      console.log(`   Sample expense date: ${expenses[0].date}, amount: ${expenses[0].amount}`);
    }
    
    // Calculate total spent
    const totalSpent = expenses.reduce((sum, exp) => sum + (exp.amount || 0), 0);
    
    // Calculate threshold amount
    const thresholdAmount = budget * (alertThreshold / 100);
    
    // Check if threshold crossed
    const shouldAlert = totalSpent >= thresholdAmount && totalSpent < budget;
    
    console.log(`${period} budget check: Budget=${currencySymbol}${budget}, Spent=${currencySymbol}${totalSpent}, Threshold=${currencySymbol}${thresholdAmount}, ShouldAlert=${shouldAlert}`);
    
    if (shouldAlert) {
      // Check if we already alerted for this amount (prevent duplicates)
      const lastAlert = await db.collection("budget_alerts").findOne({
        userId: userId,
        budgetKey: budgetKey,
        amount: totalSpent
      });
      
      if (lastAlert) {
        console.log(`⏭️ Already alerted for ${period} budget at amount ${currencySymbol}${totalSpent} on ${lastAlert.alertedAt}`);
        return;
      }
      
      console.log(`📬 Sending ${period} budget alert...`);
      
      // Send FCM notification with user's currency symbol
      await sendFCMNotification({
          fcmToken,
          title: `${capitalize(period)} Budget Alert`,
          body: `You've spent ${currencySymbol}${totalSpent.toFixed(2)} of ${currencySymbol}${budget.toFixed(2)} (${alertThreshold}% threshold reached)`,
          data: {
            type: 'budget_alert',
            period: period,
            spent: totalSpent.toString(),
            budget: budget.toString(),
            currencySymbol: currencySymbol
          }
        });
        
        // Save alert record to prevent duplicates
        await db.collection("budget_alerts").insertOne({
          userId: userId,
          budgetKey: budgetKey,
          amount: totalSpent,
          alertedAt: new Date(),
          period: period
        });
        
        console.log(`✅ Sent ${period} budget alert to user ${userId}`);
      
    } else {
      console.log(`ℹ️ ${period} budget: No alert needed (below threshold or over budget)`);
    }
    
  } catch (error) {
    console.error(`Error checking ${period} budget:`, error);
  }
}

async function sendFCMNotification({ fcmToken, title, body, data }) {
  const fcmEndpoint = 'https://fcm.googleapis.com/v1/projects/pocket-organizer-b01f8/messages:send';
  
  // Get FCM access token (you need to set up a service account)
  const accessToken = await getFCMAccessToken();
  
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
  
  try {
    const response = await context.http.post({
      url: fcmEndpoint,
      headers: {
        'Authorization': [`Bearer ${accessToken}`],
        'Content-Type': ['application/json']
      },
      body: JSON.stringify(message)
    });
    
    console.log('FCM response:', response.body.text());
    return response;
  } catch (error) {
    console.error('Error sending FCM:', error);
    throw error;
  }
}

async function getFCMAccessToken() {
  try {
    // Try the recommended way first (Atlas App Services Values/Secrets)
    const token = context.values.get("fcm_access_token");
    
    if (token) {
      console.log("   ✅ Got access token from Atlas Values");
      return token;
    }
    
    // Fallback: Try environment variables (if configured)
    if (context.environment && context.environment.values) {
      const envToken = context.environment.values.fcm_access_token;
      if (envToken) {
        console.log("   ✅ Got access token from environment");
        return envToken;
      }
    }
    
    throw new Error("FCM access token not found in Atlas Values or Environment");
  } catch (error) {
    console.error("   ❌ Error getting FCM access token:", error.message);
    throw error;
  }
}

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}


