/**
 * MongoDB Realm Function: Budget Alert Checker (DIAGNOSTIC VERSION)
 * 
 * This version has enhanced logging to diagnose FCM issues
 * Use this temporarily to find the problem, then switch back to the main version
 */

exports = async function(changeEvent) {
  const mongodb = context.services.get("mongodb-atlas");
  const db = mongodb.db("pocket_organizer");
  
  console.log("=====================================");
  console.log("🔔 TRIGGER STARTED");
  console.log("=====================================");
  
  // Get the expense document
  const expense = changeEvent.fullDocument;
  if (!expense || !expense.userId) {
    console.log("❌ No userId in expense, skipping");
    return;
  }
  
  const userId = expense.userId;
  console.log(`✅ User ID found: ${userId}`);
  
  try {
    // Get user's settings (budget limits and alert threshold)
    console.log("📥 Fetching user settings...");
    const userSettings = await db.collection("user_settings").findOne({ userId });
    
    if (!userSettings) {
      console.log("❌ No settings found for user");
      return;
    }
    
    console.log("✅ User settings found:");
    console.log(`   Daily Budget: ${userSettings.dailyBudget}`);
    console.log(`   Weekly Budget: ${userSettings.weeklyBudget}`);
    console.log(`   Monthly Budget: ${userSettings.monthlyBudget}`);
    console.log(`   Alert Threshold: ${userSettings.alertThreshold || 80}%`);
    
    const alertThreshold = userSettings.alertThreshold || 80;
    const dailyBudget = userSettings.dailyBudget;
    const weeklyBudget = userSettings.weeklyBudget;
    const monthlyBudget = userSettings.monthlyBudget;
    
    // Get user's FCM token
    console.log("📥 Fetching user FCM token...");
    const userDoc = await db.collection("users").findOne({ userId });
    
    if (!userDoc) {
      console.log("❌ User document not found!");
      return;
    }
    
    console.log("✅ User document found");
    console.log(`   Email: ${userDoc.email}`);
    console.log(`   FCM Token: ${userDoc.fcmToken ? userDoc.fcmToken.substring(0, 20) + '...' : 'NOT FOUND'}`);
    
    if (!userDoc.fcmToken) {
      console.log("❌ No FCM token found for user");
      return;
    }
    
    const fcmToken = userDoc.fcmToken;
    console.log("✅ FCM token retrieved successfully");
    
    // Check daily budget
    if (dailyBudget && dailyBudget > 0) {
      console.log("📊 Checking DAILY budget...");
      await checkAndAlert({
        userId,
        fcmToken,
        budget: dailyBudget,
        alertThreshold,
        period: 'daily',
        budgetKey: 'daily_budget',
        db
      });
    } else {
      console.log("⏭️ Skipping daily budget (not set)");
    }
    
    // Check weekly budget
    if (weeklyBudget && weeklyBudget > 0) {
      console.log("📊 Checking WEEKLY budget...");
      await checkAndAlert({
        userId,
        fcmToken,
        budget: weeklyBudget,
        alertThreshold,
        period: 'weekly',
        budgetKey: 'weekly_budget',
        db
      });
    } else {
      console.log("⏭️ Skipping weekly budget (not set)");
    }
    
    // Check monthly budget
    if (monthlyBudget && monthlyBudget > 0) {
      console.log("📊 Checking MONTHLY budget...");
      await checkAndAlert({
        userId,
        fcmToken,
        budget: monthlyBudget,
        alertThreshold,
        period: 'monthly',
        budgetKey: 'monthly_budget',
        db
      });
    } else {
      console.log("⏭️ Skipping monthly budget (not set)");
    }
    
    console.log("=====================================");
    console.log("✅ TRIGGER COMPLETED");
    console.log("=====================================");
    
  } catch (error) {
    console.error("❌❌❌ ERROR in main function:", error);
    console.error("Stack trace:", error.stack);
  }
};

async function checkAndAlert({ userId, fcmToken, budget, alertThreshold, period, budgetKey, db }) {
  try {
    console.log(`\n--- ${period.toUpperCase()} BUDGET CHECK ---`);
    
    // Calculate date range based on period
    const now = new Date();
    let startDate, endDate;
    
    if (period === 'daily') {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 1);
    } else if (period === 'weekly') {
      const dayOfWeek = now.getDay();
      const diff = now.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1);
      startDate = new Date(now.getFullYear(), now.getMonth(), diff);
      startDate.setHours(0, 0, 0, 0);
      endDate = new Date(startDate);
      endDate.setDate(endDate.getDate() + 7);
    } else if (period === 'monthly') {
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
      endDate = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    }
    
    console.log(`📅 Date range: ${startDate.toISOString()} to ${endDate.toISOString()}`);
    
    // Get expenses for the period
    const expenses = await db.collection("expenses")
      .find({
        userId: userId,
        date: { $gte: startDate, $lt: endDate }
      })
      .toArray();
    
    console.log(`💰 Found ${expenses.length} expenses in period`);
    
    // Calculate total spent
    const totalSpent = expenses.reduce((sum, exp) => sum + (exp.amount || 0), 0);
    
    // Calculate threshold amount
    const thresholdAmount = budget * (alertThreshold / 100);
    
    // Check if threshold crossed
    const shouldAlert = totalSpent >= thresholdAmount && totalSpent < budget;
    
    console.log(`📊 Budget: ${budget}`);
    console.log(`📊 Total Spent: ${totalSpent}`);
    console.log(`📊 Threshold (${alertThreshold}%): ${thresholdAmount}`);
    console.log(`📊 Should Alert: ${shouldAlert}`);
    
    if (shouldAlert) {
      console.log("⚠️ THRESHOLD CROSSED! Checking if already alerted...");
      
      // Check if we already alerted for this amount (prevent duplicates)
      const lastAlert = await db.collection("budget_alerts").findOne({
        userId: userId,
        budgetKey: budgetKey,
        amount: totalSpent
      });
      
      if (lastAlert) {
        console.log(`⏭️ Already alerted for this amount on ${lastAlert.alertedAt}`);
        return;
      }
      
      console.log("📤 No previous alert found. Sending FCM notification...");
      
      // Send FCM notification
      try {
        await sendFCMNotification({
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
        
        console.log("✅ FCM notification sent successfully!");
        
        // Save alert record to prevent duplicates
        await db.collection("budget_alerts").insertOne({
          userId: userId,
          budgetKey: budgetKey,
          amount: totalSpent,
          alertedAt: new Date(),
          period: period
        });
        
        console.log(`✅ Alert record saved to database`);
        
      } catch (fcmError) {
        console.error("❌❌❌ FCM SEND ERROR:", fcmError);
        console.error("Error details:", JSON.stringify(fcmError));
        throw fcmError;
      }
    } else {
      console.log("✅ No alert needed (threshold not crossed or budget exceeded)");
    }
    
  } catch (error) {
    console.error(`❌❌❌ ERROR in checkAndAlert (${period}):`, error);
    console.error("Error stack:", error.stack);
  }
}

async function sendFCMNotification({ fcmToken, title, body, data }) {
  console.log("\n🚀 SENDING FCM NOTIFICATION");
  console.log(`📱 Token: ${fcmToken.substring(0, 20)}...`);
  console.log(`📧 Title: ${title}`);
  console.log(`📝 Body: ${body}`);
  
  const fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';
  
  // Get server key from MongoDB Atlas Secret
  console.log("🔑 Fetching FCM Server Key from Atlas Values...");
  let serverKey;
  try {
    serverKey = await context.values.get("fcm_server_key");
  } catch (keyError) {
    console.error("❌❌❌ FAILED TO GET SERVER KEY:", keyError);
    throw new Error("FCM Server Key not found in MongoDB Atlas Values. Please add it!");
  }
  
  if (!serverKey) {
    console.error("❌❌❌ FCM Server Key is NULL or UNDEFINED!");
    throw new Error("FCM Server Key not configured in MongoDB Atlas Values");
  }
  
  console.log(`✅ Server Key retrieved: ${serverKey.substring(0, 20)}...`);
  
  const message = {
    to: fcmToken,
    notification: {
      title: title,
      body: body,
      sound: 'default',
      badge: '1'
    },
    data: data || {},
    priority: 'high'
  };
  
  console.log("📦 Message payload:", JSON.stringify(message, null, 2));
  
  try {
    console.log(`📤 Sending POST request to: ${fcmEndpoint}`);
    
    const response = await context.http.post({
      url: fcmEndpoint,
      headers: {
        'Authorization': [`key=${serverKey}`],
        'Content-Type': ['application/json']
      },
      body: JSON.stringify(message)
    });
    
    console.log(`✅ FCM API Response Status: ${response.statusCode}`);
    
    const responseBody = response.body.text();
    console.log(`📥 FCM API Response Body: ${responseBody}`);
    
    // Check if notification was sent successfully
    try {
      const responseData = JSON.parse(responseBody);
      console.log("📊 Parsed Response:", JSON.stringify(responseData, null, 2));
      
      if (responseData.success === 1) {
        console.log('🎉🎉🎉 FCM NOTIFICATION SENT SUCCESSFULLY!');
      } else if (responseData.failure === 1) {
        console.error('❌❌❌ FCM NOTIFICATION FAILED!');
        console.error('Error details:', responseData.results);
        throw new Error(`FCM send failed: ${JSON.stringify(responseData.results)}`);
      }
    } catch (parseError) {
      console.error("⚠️ Could not parse response:", parseError);
      console.log("Raw response:", responseBody);
    }
    
    return response;
  } catch (httpError) {
    console.error('❌❌❌ HTTP REQUEST ERROR:', httpError);
    console.error('Error details:', JSON.stringify(httpError));
    throw httpError;
  }
}

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

