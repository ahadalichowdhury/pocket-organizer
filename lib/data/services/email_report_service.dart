import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailReportService {
  /// Send email with PDF attachment
  static Future<bool> sendReportEmail({
    required String recipientEmail,
    required String subject,
    required String body,
    required File pdfFile,
  }) async {
    try {
      // Get email configuration from environment variables
      final smtpHost = dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
      final smtpPort = int.tryParse(dotenv.env['SMTP_PORT'] ?? '587') ?? 587;
      final senderEmail = dotenv.env['SENDER_EMAIL'];
      final senderPassword = dotenv.env['SENDER_PASSWORD'];
      final senderName = dotenv.env['SENDER_NAME'] ?? 'Pocket Organizer';

      if (senderEmail == null || senderPassword == null) {
        print('❌ [Email] SMTP credentials not configured in .env file');
        return false;
      }

      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: senderEmail,
        password: senderPassword,
        // For Gmail, you need to enable "Less secure app access" or use App Password
        // ssl: true, // Use SSL for port 465
        // allowInsecure: true, // For port 587 with STARTTLS
      );

      // Create email message
      final message = Message()
        ..from = Address(senderEmail, senderName)
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..html = '''
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <div style="max-width: 600px; margin: 0 auto;">
                <h2 style="color: #1976D2;">📊 $subject</h2>
                <p style="color: #333; line-height: 1.6;">
                  $body
                </p>
                <div style="background-color: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                  <p style="margin: 0; color: #666;">
                    📎 Your expense report is attached as a PDF file.
                  </p>
                </div>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
                <p style="color: #999; font-size: 12px;">
                  This is an automated report from Pocket Organizer.<br>
                  You can manage your report settings in the app.
                </p>
              </div>
            </body>
          </html>
        '''
        ..attachments.add(FileAttachment(pdfFile));

      // Send email
      final sendReport = await send(message, smtpServer);
      print('✅ [Email] Report sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('❌ [Email] Failed to send report: $e');
      return false;
    }
  }

  /// Send a test email to verify SMTP configuration
  static Future<bool> sendTestEmail(String recipientEmail) async {
    try {
      final smtpHost = dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
      final smtpPort = int.tryParse(dotenv.env['SMTP_PORT'] ?? '587') ?? 587;
      final senderEmail = dotenv.env['SENDER_EMAIL'];
      final senderPassword = dotenv.env['SENDER_PASSWORD'];

      if (senderEmail == null || senderPassword == null) {
        print('❌ [Email] SMTP credentials not configured');
        return false;
      }

      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: senderEmail,
        password: senderPassword,
      );

      final message = Message()
        ..from = Address(senderEmail, 'Pocket Organizer')
        ..recipients.add(recipientEmail)
        ..subject = '✅ Email Configuration Test - Pocket Organizer'
        ..html = '''
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2 style="color: #1976D2;">🎉 Email Configuration Successful!</h2>
              <p>Your Pocket Organizer app is now configured to send automated expense reports.</p>
              <p>You will receive reports according to your schedule:</p>
              <ul>
                <li>📅 Daily Reports</li>
                <li>📅 Weekly Reports</li>
                <li>📅 Monthly Reports</li>
              </ul>
            </body>
          </html>
        ''';

      await send(message, smtpServer);
      print('✅ [Email] Test email sent successfully');
      return true;
    } catch (e) {
      print('❌ [Email] Test email failed: $e');
      return false;
    }
  }
}
