# 🐛 Debug: Why Budget Alerts Are Not Sending

## 🔍 **ISSUE: Alerts Not Sending**

### **Root Cause:**
The trigger checks if an alert was **already sent for the exact same amount**. This prevents duplicate notifications.

**Example:**
- You spent `৳500` → Alert sent ✅ → Record saved in `budget_alerts`
- You add another expense → Total still `৳500` → Alert NOT sent ⏭️ (already alerted)
- You spend more → Total now `৳550` → New alert sent ✅ (different amount)

---

## 🛠️ **SOLUTION: Clear Old Alert Records**

### **Option 1: Clear All Alerts (Recommended for Testing)**

Run this in **MongoDB Atlas → Data Explorer → pocket_organizer → budget_alerts**:

```javascript
// Delete ALL budget alerts (fresh start)
db.budget_alerts.deleteMany({})
```

### **Option 2: Clear Alerts for Specific User**

```javascript
// Replace with your userId
db.budget_alerts.deleteMany({ 
  userId: "x8DjU4w7FiSvtHBQ0JAFWf5X0W42" 
})
```

### **Option 3: Clear Specific Period**

```javascript
// Clear only daily alerts
db.budget_alerts.deleteMany({ 
  userId: "x8DjU4w7FiSvtHBQ0JAFWf5X0W42",
  budgetKey: "daily_budget"
})

// Clear only weekly alerts
db.budget_alerts.deleteMany({ 
  userId: "x8DjU4w7FiSvtHBQ0JAFWf5X0W42",
  budgetKey: "weekly_budget"
})

// Clear only monthly alerts
db.budget_alerts.deleteMany({ 
  userId: "x8DjU4w7FiSvtHBQ0JAFWf5X0W42",
  budgetKey: "monthly_budget"
})
```

---

## 📊 **Check Current Alerts**

### **See what alerts exist:**

```javascript
// View all alerts
db.budget_alerts.find().pretty()

// View alerts for specific user
db.budget_alerts.find({ 
  userId: "x8DjU4w7FiSvtHBQ0JAFWf5X0W42" 
}).pretty()
```

**Output will show:**
```javascript
{
  "_id": ObjectId("..."),
  "userId": "x8DjU4w7FiSvtHBQ0JAFWf5X0W42",
  "budgetKey": "daily_budget",
  "amount": 500,              // ← Alert was sent when total was 500
  "alertedAt": ISODate("2025-10-24T10:30:00Z"),
  "period": "daily"
}
```

---

## 📝 **Understanding the Logs**

### **After deploying the improved logging, you'll see:**

#### **Scenario 1: Alert Sent**
```
📊 Checking budget for user: x8DjU4...
💰 Currency: ৳, Alert Threshold: 90%
✅ FCM token found
daily budget check: Budget=৳1000, Spent=৳920, Threshold=৳900, ShouldAlert=true
📬 Sending daily budget alert...
✅ Sent daily budget alert to user x8DjU4...
```

#### **Scenario 2: Already Alerted (Duplicate)**
```
📊 Checking budget for user: x8DjU4...
💰 Currency: ৳, Alert Threshold: 90%
✅ FCM token found
daily budget check: Budget=৳1000, Spent=৳920, Threshold=৳900, ShouldAlert=true
⏭️ Already alerted for daily budget at amount ৳920 on 2025-10-24T10:30:00.000+00:00
```

#### **Scenario 3: Below Threshold**
```
📊 Checking budget for user: x8DjU4...
💰 Currency: ৳, Alert Threshold: 90%
✅ FCM token found
daily budget check: Budget=৳1000, Spent=৳500, Threshold=৳900, ShouldAlert=false
ℹ️ daily budget: No alert needed (below threshold or over budget)
```

#### **Scenario 4: Over Budget**
```
📊 Checking budget for user: x8DjU4...
💰 Currency: ৳, Alert Threshold: 90%
✅ FCM token found
daily budget check: Budget=৳1000, Spent=৳1200, Threshold=৳900, ShouldAlert=false
ℹ️ daily budget: No alert needed (below threshold or over budget)
```

---

## 🧪 **Testing Steps**

### **1. Deploy Updated Function**
- Go to MongoDB Atlas → App Services → Functions
- Update `checkBudgetAndSendAlert`
- Deploy changes

### **2. Clear Old Alerts**
```javascript
db.budget_alerts.deleteMany({ 
  userId: "YOUR_USER_ID" 
})
```

### **3. Set Test Budget**
In your app:
- Settings → Budget Settings
- Daily Budget: `100`
- Alert Threshold: `80%` (will alert at `৳80`)

### **4. Add Test Expense**
- Add expense: Amount = `85`
- This crosses 80% threshold
- Should trigger alert ✅

### **5. Check Logs**
MongoDB Atlas → App Services → Logs

**Should see:**
```
📊 Checking budget for user: YOUR_USER_ID
💰 Currency: ৳, Alert Threshold: 80%
✅ FCM token found
daily budget check: Budget=৳100, Spent=৳85, Threshold=৳80, ShouldAlert=true
📬 Sending daily budget alert...
✅ Sent daily budget alert to user YOUR_USER_ID
```

### **6. Check Notification**
- Should receive push notification on phone
- Message: "You've spent ৳85.00 of ৳100.00 (80% threshold reached)"

### **7. Add Another Small Expense**
- Add expense: Amount = `5`
- Total now: `৳90`
- **New alert should be sent** (different amount!)

---

## ❓ **Troubleshooting**

### **Q: I cleared alerts but still no notification?**

**A:** Check the logs for these issues:

1. **No FCM token:**
   ```
   ⚠️ No FCM token found for user
   ```
   **Fix:** Logout and login again to register FCM token

2. **Below threshold:**
   ```
   ℹ️ daily budget: No alert needed (below threshold or over budget)
   ```
   **Fix:** Check if `Spent >= Threshold`
   - Example: Spent=`৳70`, Threshold=`৳80` → No alert (need to spend more)

3. **Over budget:**
   ```
   ShouldAlert=false
   ```
   **Fix:** Alerts only send when between threshold and budget
   - Example: Budget=`৳100`, Spent=`৳120` → No alert (already over budget)

### **Q: Alert sent but I didn't receive it?**

**A:** Check notification permissions:
- Android Settings → Apps → Pocket Organizer → Notifications → Enabled
- Check notification channel: "Budget Alerts" should be enabled

### **Q: How often can I get alerts?**

**A:** You get ONE alert per spending amount:
- Spend `৳80` → Alert sent ✅
- Spend `৳5` more (total `৳85`) → New alert sent ✅
- Add 0 more (total still `৳85`) → No alert ⏭️ (already alerted)

---

## 🔄 **How It Works**

```
┌─────────────────────────────────────────────┐
│ 1. You add an expense                       │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 2. MongoDB trigger runs                     │
│    - Calculate total spent for period       │
│    - Check if >= threshold                  │
└───────────────┬─────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│ 3. Check if already alerted                 │
│    - Query: budget_alerts collection        │
│    - Match: userId + budgetKey + amount     │
└───────────────┬─────────────────────────────┘
                │
       ┌────────┴────────┐
       │                 │
       ▼                 ▼
  Found              Not Found
  (Skip)             (Send Alert)
       │                 │
       ▼                 ▼
┌──────────────┐  ┌──────────────────────────┐
│ ⏭️ Already   │  │ 📬 Send FCM notification │
│   alerted    │  │ 💾 Save alert record     │
└──────────────┘  └──────────────────────────┘
```

---

## 📌 **Key Points**

1. ✅ **Alerts are amount-based** - Different amount = New alert
2. ✅ **No duplicate alerts** - Same amount = Skip
3. ✅ **Clear alerts to re-test** - Delete from `budget_alerts` collection
4. ✅ **Check logs for details** - MongoDB Atlas → App Services → Logs
5. ✅ **Alerts only between threshold and budget** - Not below, not over

---

**Last Updated:** October 24, 2025  
**Related Files:**
- `mongodb_functions/checkBudgetAndSendAlert.js`
- `mongodb_functions/DEPLOY_INSTRUCTIONS.md`

