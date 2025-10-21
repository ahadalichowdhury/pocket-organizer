/**
 * MongoDB Realm Function: Budget Alert Checker (FCM V1 API)
 * 
 * This version uses the modern FCM V1 API with OAuth 2.0
 * No external packages needed - uses MongoDB Atlas built-in APIs
 * 
 * REQUIRED MONGODB ATLAS VALUES (as Secrets):
 * - firebase_private_key: Service account private key
 * - firebase_client_email: Service account email
 * - firebase_project_id: Firebase project ID
 * 
 * SETUP:
 * 1. Download service account JSON from Firebase Console
 * 2. Add the 3 values above to MongoDB Atlas Values as Secrets
 * 3. Upload this function to MongoDB Atlas
 * 4. Create trigger on expenses collection (Insert, Update)
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
    
    // Calculate date range
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
    
    // Get expenses for period
    const expenses = await db.collection("expenses")
      .find({
        userId: userId,
        date: { $gte: startDate, $lt: endDate }
      })
      .toArray();
    
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
    }
    
  } catch (error) {
    console.error(`   ❌ Error in ${period} check:`, error);
  }
}

async function sendFCMNotificationV1({ fcmToken, title, body, data }) {
  try {
    console.log("\n🚀 Sending FCM V1 notification...");
    
    // Get OAuth access token
    const accessToken = await getAccessToken();
    
    // Get project ID
    const projectId = await context.values.get("firebase_project_id");
    if (!projectId) {
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
    
    if (response.statusCode === 200) {
      console.log("   ✅ FCM notification sent successfully!");
      return true;
    } else {
      const responseBody = response.body.text();
      console.error(`   ❌ FCM error: ${responseBody}`);
      throw new Error(`FCM failed: ${responseBody}`);
    }
    
  } catch (error) {
    console.error("   ❌ Error sending FCM:", error);
    throw error;
  }
}

async function getAccessToken() {
  try {
    console.log("   🔑 Generating OAuth token...");
    
    // Get service account credentials from MongoDB Atlas Secrets
    const privateKey = await context.values.get("firebase_private_key");
    const clientEmail = await context.values.get("firebase_client_email");
    
    if (!privateKey || !clientEmail) {
      throw new Error("Firebase service account credentials not configured");
    }
    
    // Create JWT
    const now = Math.floor(Date.now() / 1000);
    const expires = now + 3600; // 1 hour
    
    const jwtHeader = {
      alg: "RS256",
      typ: "JWT"
    };
    
    const jwtClaim = {
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: expires,
      iat: now
    };
    
    // Encode header and claim
    const headerBase64 = base64UrlEncode(JSON.stringify(jwtHeader));
    const claimBase64 = base64UrlEncode(JSON.stringify(jwtClaim));
    const signatureInput = `${headerBase64}.${claimBase64}`;
    
    // Sign with private key
    const signature = await signRS256(signatureInput, privateKey);
    const jwt = `${signatureInput}.${signature}`;
    
    console.log("   ✅ JWT created");
    
    // Exchange JWT for access token
    const tokenResponse = await context.http.post({
      url: "https://oauth2.googleapis.com/token",
      headers: {
        'Content-Type': ['application/x-www-form-urlencoded']
      },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
    });
    
    if (tokenResponse.statusCode !== 200) {
      throw new Error(`Token exchange failed: ${tokenResponse.body.text()}`);
    }
    
    const tokenData = JSON.parse(tokenResponse.body.text());
    console.log("   ✅ Access token obtained");
    
    return tokenData.access_token;
    
  } catch (error) {
    console.error("   ❌ Error getting access token:", error);
    throw error;
  }
}

async function signRS256(message, privateKeyPem) {
  try {
    // Use MongoDB Realm's built-in crypto to sign with RS256
    const utils = context.utils;
    
    // Convert PEM to proper format
    let key = privateKeyPem.replace(/\\n/g, '\n');
    
    // Create signature using RSASSA-PKCS1-v1_5 with SHA-256
    const signature = await utils.crypto.sign(
      'RSA-SHA256',
      key,
      message
    );
    
    return base64UrlEncode(signature);
    
  } catch (error) {
    console.error("Signing error:", error);
    throw new Error(`Failed to sign JWT: ${error.message}`);
  }
}

function base64UrlEncode(str) {
  // Convert string to base64
  let base64;
  if (typeof str === 'string') {
    base64 = BSON.Binary.fromBase64(
      context.utils.crypto.encrypt('base64', str)
    ).toString('base64');
  } else {
    base64 = str.toString('base64');
  }
  
  // Make URL-safe
  return base64
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

