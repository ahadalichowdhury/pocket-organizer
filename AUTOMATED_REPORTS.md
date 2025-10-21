# 📧 Automated Expense Reports Feature

## Overview

The Pocket Organizer app now includes an **Automated Email Reports** feature that sends expense reports as PDF attachments to your email on a daily, weekly, or monthly schedule.

## ✨ Features

### 1. **PDF Report Generation**

- Professional PDF reports with:
  - Executive summary (total, transactions, average)
  - Category breakdown with percentages
  - Payment method analysis
  - Complete transaction list
  - Charts and tables

### 2. **Automated Scheduling**

- **Daily Reports** - Every day at 9:00 AM
- **Weekly Reports** - Every Monday at 9:00 AM
- **Monthly Reports** - 1st of every month at 9:00 AM

### 3. **Email Delivery**

- HTML formatted emails
- PDF attachment
- Summary in email body
- Professional branding

### 4. **Notifications**

- Local notification when report is sent
- Success/failure notifications
- Low battery and network-aware

## 🚀 Setup Instructions

### Step 1: Configure SMTP Email

Edit your `.env` file and add:

```env
# Email Report Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SENDER_EMAIL=your-email@gmail.com
SENDER_PASSWORD=your-app-password-here
SENDER_NAME=Pocket Organizer
```

### Step 2: For Gmail Users

1. Enable 2-Factor Authentication on your Google account
2. Go to https://myaccount.google.com/apppasswords
3. Create a new App Password for "Mail"
4. Use the generated 16-character password in `SENDER_PASSWORD`

### Step 3: For Outlook Users

```env
SMTP_HOST=smtp-mail.outlook.com
SMTP_PORT=587
SENDER_EMAIL=your-email@outlook.com
SENDER_PASSWORD=your-password
```

### Step 4: Enable Reports in App

1. Open **Settings** → **Automated Reports**
2. Toggle on:
   - Daily Reports
   - Weekly Reports
   - Monthly Reports
3. Reports will be sent to your logged-in email

## 📄 Report Contents

### Summary Section

- 💰 Total Expenses
- 📊 Number of Transactions
- 📈 Average Expense
- 📅 Report Period

### Category Breakdown

- All expense categories
- Amount per category
- Percentage of total
- Sorted by amount

### Payment Methods

- All payment methods used
- Amount per method
- Transaction count

### Transaction List

- Date, Category, Description, Amount
- Sorted by date (newest first)
- Complete transaction history

## 🔧 Technical Implementation

### Services Created

1. **`PdfReportService`** (`lib/data/services/pdf_report_service.dart`)

   - Generates professional PDF reports
   - Customizable with currency symbols
   - Charts and tables
   - Responsive layout

2. **`EmailReportService`** (`lib/data/services/email_report_service.dart`)

   - SMTP email sending
   - HTML email templates
   - PDF attachments
   - Test email function

3. **`AutomatedReportService`** (`lib/data/services/automated_report_service.dart`)
   - Background task scheduling
   - WorkManager integration
   - Cron-like scheduling
   - Notification system

### Background Tasks

Uses **WorkManager** for reliable background execution:

- Works even when app is closed
- Battery-efficient
- Network-aware
- Persists across device reboots

### Packages Added

```yaml
dependencies:
  pdf: ^3.10.7 # PDF generation
  printing: ^5.12.0 # PDF utilities
  mailer: ^6.0.1 # SMTP email
  workmanager: ^0.5.2 # Background tasks
```

## 📱 User Flow

### Enabling Reports

1. User opens Settings
2. Taps "Email Reports"
3. Toggles report types (Daily/Weekly/Monthly)
4. Background tasks are scheduled automatically

### Receiving Reports

1. At scheduled time, background task triggers
2. App generates PDF from expense data
3. Email is sent with PDF attachment
4. User receives notification: "📧 Report Sent!"
5. PDF is automatically deleted after sending

## 🎨 UI Components

### Settings Screen Addition

New section: **Automated Reports**

- Email Reports tile
- Opens configuration dialog

### Configuration Dialog

- Toggle switches for each report type
- Descriptive subtitles (schedule info)
- Setup instructions info box
- "Send Test Report" button

## ⚙️ Configuration Options

### Saved in Hive

```dart
'daily_report_enabled': bool
'weekly_report_enabled': bool
'monthly_report_enabled': bool
'daily_report_hour': int (default: 9)
'weekly_report_day': int (default: 1 = Monday)
'monthly_report_day': int (default: 1 = 1st)
'weekly_report_hour': int (default: 9)
'monthly_report_hour': int (default: 9)
```

## 🔒 Security & Privacy

### Email Security

- ✅ Uses SMTP with TLS encryption
- ✅ Credentials stored in `.env` (not in code)
- ✅ Supports App Passwords (recommended)
- ✅ `.env` file in `.gitignore`

### Data Privacy

- ✅ PDFs generated locally on device
- ✅ Sent only to user's own email
- ✅ Temporary PDFs deleted after sending
- ✅ No data sent to third-party servers

## 📊 Report Schedule Details

### Daily Report

- **Time**: 9:00 AM every day
- **Data**: Previous 24 hours
- **Best for**: Daily expense trackers

### Weekly Report

- **Time**: 9:00 AM every Monday
- **Data**: Previous 7 days
- **Best for**: Weekly budget reviewers

### Monthly Report

- **Time**: 9:00 AM on 1st of month
- **Data**: Previous 30 days
- **Best for**: Monthly financial planning

## 🐛 Troubleshooting

### "Email not sending"

- ✅ Check `.env` file has correct SMTP settings
- ✅ For Gmail, use App Password (not regular password)
- ✅ Check internet connection
- ✅ Verify email and password are correct

### "No notification received"

- ✅ Check notification permissions
- ✅ Ensure app is not in battery saver mode
- ✅ Check if reports are enabled in settings

### "Report is empty"

- ✅ Ensure you have expenses in the date range
- ✅ Check if date range is correct
- ✅ Daily reports cover previous 24 hours

## 🎯 Future Enhancements

Potential improvements:

- [ ] Customizable report times
- [ ] Custom report frequency
- [ ] Multiple recipient emails
- [ ] PDF customization options
- [ ] Export to Google Drive/Dropbox
- [ ] Chart/graph visualizations in PDF
- [ ] Comparison with previous period
- [ ] Budget vs actual analysis

## 📝 Code Files Modified

### New Files Created

1. `lib/data/services/pdf_report_service.dart` - PDF generation
2. `lib/data/services/email_report_service.dart` - Email sending
3. `lib/data/services/automated_report_service.dart` - Background scheduling

### Modified Files

1. `pubspec.yaml` - Added dependencies
2. `lib/screens/settings/settings_screen.dart` - Added UI
3. `ENV_SETUP.md` - Added email configuration guide

## 🔗 Related Documentation

- **ENV_SETUP.md** - Environment configuration
- **README.md** - Project overview
- **DEVELOPMENT.md** - Development guide

## 💡 Tips

1. **Test First**: Use "Send Test Report" before enabling automated reports
2. **Check Spam**: First email might go to spam folder
3. **Battery Optimization**: Disable battery optimization for the app
4. **Backup**: Keep SMTP credentials safe and backed up
5. **Multiple Accounts**: Use different email for receiving if desired

## 📧 Support

For issues with automated reports:

1. Check ENV_SETUP.md for configuration
2. Verify SMTP credentials
3. Test with "Send Test Report" button
4. Check app notifications for error messages

---

**Built with ❤️ for Pocket Organizer**
