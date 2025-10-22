import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Simple email service for sending HTML emails without attachments
/// Used by warranty reminders
class SimpleEmailService {
  /// Send HTML email without attachments
  static Future<bool> sendHtmlEmail({
    required String recipientEmail,
    required String subject,
    required String htmlBody,
    String? plainTextBody,
  }) async {
    try {
      print('📧 [SimpleEmail] Sending email...');
      print('   To: $recipientEmail');
      print('   Subject: $subject');

      // Get email configuration from environment variables
      final smtpHost = dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
      final smtpPort = int.tryParse(dotenv.env['SMTP_PORT'] ?? '587') ?? 587;
      final senderEmail = dotenv.env['SENDER_EMAIL'];
      final senderPassword = dotenv.env['SENDER_PASSWORD'];
      final senderName = dotenv.env['SENDER_NAME'] ?? 'Pocket Organizer';

      if (senderEmail == null || senderPassword == null) {
        print('❌ [SimpleEmail] SMTP credentials not configured in .env file');
        print(
            '   Please add SENDER_EMAIL and SENDER_PASSWORD to your .env file');
        return false;
      }

      print('✅ [SimpleEmail] SMTP configured: $smtpHost:$smtpPort');
      print('   Sender: $senderEmail');

      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: senderEmail,
        password: senderPassword,
        // For Gmail, use App Password (not regular password)
        // ssl: true, // Use for port 465
        // allowInsecure: true, // Use for port 587 with STARTTLS
      );

      // Create email message
      final message = Message()
        ..from = Address(senderEmail, senderName)
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..html = htmlBody;

      // Add plain text version if provided
      if (plainTextBody != null) {
        message.text = plainTextBody;
      }

      print('📤 [SimpleEmail] Sending email via SMTP...');

      // Send email
      final sendReport = await send(message, smtpServer);

      print('✅ [SimpleEmail] Email sent successfully!');
      print('   Mail: ${sendReport.mail}');
      print('   Response: ${sendReport.toString()}');

      return true;
    } catch (e) {
      print('❌ [SimpleEmail] Failed to send email: $e');

      // Provide helpful error messages
      if (e.toString().contains('Authentication')) {
        print(
            '   💡 Tip: Make sure you\'re using a Gmail App Password, not your regular password');
        print('   Generate one at: https://myaccount.google.com/apppasswords');
      } else if (e.toString().contains('Connection')) {
        print('   💡 Tip: Check your internet connection and SMTP settings');
      }

      return false;
    }
  }

  /// Test email configuration
  static Future<bool> testEmailConfiguration() async {
    try {
      final smtpHost = dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
      final smtpPort = int.tryParse(dotenv.env['SMTP_PORT'] ?? '587') ?? 587;
      final senderEmail = dotenv.env['SENDER_EMAIL'];
      final senderPassword = dotenv.env['SENDER_PASSWORD'];

      if (senderEmail == null || senderPassword == null) {
        print('❌ [SimpleEmail] SMTP credentials not configured');
        return false;
      }

      print('✅ [SimpleEmail] SMTP Configuration:');
      print('   Host: $smtpHost');
      print('   Port: $smtpPort');
      print('   Email: $senderEmail');
      print('   Password: ${senderPassword.substring(0, 4)}****');

      return true;
    } catch (e) {
      print('❌ [SimpleEmail] Configuration error: $e');
      return false;
    }
  }
}
