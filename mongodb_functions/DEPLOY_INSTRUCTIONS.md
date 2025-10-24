# 🚀 Deploy MongoDB Function Updates

## ✅ Fixed: Currency Symbol in Budget Alerts

**Problem:** Budget alerts showed hardcoded `$` symbol  
**Solution:** Now reads `currencySymbol` from `user_settings` collection

---

## 📋 How to Deploy to MongoDB Atlas

### **Option 1: MongoDB Atlas Web UI** (RECOMMENDED)

1. **Go to MongoDB Atlas:**

   - Login: https://cloud.mongodb.com/
   - Select your project: `pocket-organizer`
   - Click **App Services** (left sidebar)
   - Click your app name

2. **Update the Function:**

   - Click **Functions** (left sidebar)
   - Find function: `checkBudgetAndSendAlert`
   - Click **Edit**
   - Replace the entire code with contents from:
     ```
     mongodb_functions/checkBudgetAndSendAlert.js
     ```
   - Click **Save**

3. **Deploy Changes:**

   - Click **REVIEW DRAFT & DEPLOY** (top-right blue button)
   - Review changes
   - Click **Deploy**
   - Wait for deployment to complete (~10-30 seconds)

4. **Verify Deployment:**
   - Check deployment status: **Deployed** ✅
   - Test by adding a new expense that crosses your budget threshold
   - Notification should now show: `৳100.00` instead of `$100.00`

---

### **Option 2: MongoDB Realm CLI** (Advanced)

```bash
# Install Realm CLI (if not already installed)
npm install -g mongodb-realm-cli

# Login
realm-cli login --api-key YOUR_PUBLIC_KEY --private-api-key YOUR_PRIVATE_KEY

# Pull current config
realm-cli pull

# Update the function file
# (Code is already updated in your local repo)

# Push changes
realm-cli push

# Verify deployment
realm-cli logs
```

---

## 🧪 Testing

### **Test Budget Alert:**

1. **Set a low budget:**

   - Go to Settings → Budget Settings
   - Set Daily Budget: `100`
   - Set Alert Threshold: `80%`

2. **Add an expense:**

   - Add expense: Amount = `85`
   - This crosses 80% of 100

3. **Check notification:**

   - Notification should say: `You've spent ৳85.00 of ৳100.00`
   - NOT: `You've spent $85.00 of $100.00`

4. **Check MongoDB logs:**
   ```
   MongoDB Atlas → App Services → Logs
   Look for: "currencySymbol: ৳"
   ```

---

## 📝 What Changed

### **Line 132-133: Fetch Currency Symbol**

```javascript
// Get user settings for currency symbol
const userSettings = await db.collection("user_settings").findOne({ userId });
const currencySymbol = userSettings?.currencySymbol || "$";
```

### **Line 173: Use in Notification**

```javascript
body: `You've spent ${currencySymbol}${totalSpent.toFixed(2)} of ${currencySymbol}${budget.toFixed(2)} (${alertThreshold}% threshold reached)`,
```

### **Line 179: Include in Data Payload**

```javascript
data: {
  type: 'budget_alert',
  period: period,
  spent: totalSpent.toString(),
  budget: budget.toString(),
  currencySymbol: currencySymbol  // ← NEW!
}
```

---

## ⚠️ Important Notes

1. **Only update `checkBudgetAndSendAlert.js`**

   - Other files (`*_V1_SIMPLE`, `*_DIAGNOSTIC`, etc.) are old test versions
   - They are NOT deployed and NOT used

2. **No trigger changes needed**

   - The database trigger setup remains the same
   - Only the function code is updated

3. **Backward compatible**

   - If `currencySymbol` is not set, defaults to `$`
   - Old users without currency symbol will still work

4. **Applies to all budget types**
   - Daily budget alerts ✅
   - Weekly budget alerts ✅
   - Monthly budget alerts ✅

---

## 🎉 Benefits

✅ **Localized currency display**  
✅ **No more confusing $ for non-USD users**  
✅ **Respects user's currency preference**  
✅ **Works with all currencies:** `৳`, `₹`, `€`, `£`, `¥`, `₦`, etc.

---

## 🆘 Troubleshooting

### **Notification still shows `$`?**

1. Check MongoDB deployment status
2. Verify function was saved and deployed
3. Clear budget_alerts collection to trigger new alert:
   ```javascript
   db.budget_alerts.deleteMany({ userId: "YOUR_USER_ID" });
   ```
4. Add new expense to trigger alert

### **Function deployment failed?**

1. Check MongoDB Atlas logs for errors
2. Verify syntax (JavaScript, not TypeScript)
3. Ensure no external dependencies (only use built-in context APIs)

---

**Last Updated:** October 24, 2025  
**Commit:** `0fa08ae`  
**Status:** ✅ Ready for Production
