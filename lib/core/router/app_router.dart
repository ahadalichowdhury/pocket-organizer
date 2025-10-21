import 'package:flutter/material.dart';
import 'package:pocket_organizer/main.dart'; // Import for AppHome
import 'package:pocket_organizer/screens/auth/login_screen.dart';
import 'package:pocket_organizer/screens/auth/onboarding_screen.dart';
import 'package:pocket_organizer/screens/auth/signup_screen.dart';
import 'package:pocket_organizer/screens/documents/capture_document_screen.dart';
import 'package:pocket_organizer/screens/documents/document_details_screen.dart';
import 'package:pocket_organizer/screens/expenses/expense_analytics_screen.dart';
import 'package:pocket_organizer/screens/expenses/expenses_screen.dart';
import 'package:pocket_organizer/screens/folders/folder_details_screen.dart';
import 'package:pocket_organizer/screens/folders/folders_screen.dart';
import 'package:pocket_organizer/screens/notifications/notifications_screen.dart';
import 'package:pocket_organizer/screens/search/search_screen.dart';
import 'package:pocket_organizer/screens/settings/settings_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    print(
        '🧭 [Router] Navigating to: ${settings.name} with args: ${settings.arguments}');

    switch (settings.name) {
      case '/':
        print('🧭 [Router] Building OnboardingScreen');
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case '/login':
        print('🧭 [Router] Building LoginScreen');
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case '/signup':
        print('🧭 [Router] Building SignupScreen');
        return MaterialPageRoute(builder: (_) => const SignupScreen());

      case '/home':
        print('🧭 [Router] Building AppHome (with bottom navigation)');
        return MaterialPageRoute(builder: (_) => const AppHome());

      case '/folders':
        print('🧭 [Router] Building FoldersScreen');
        return MaterialPageRoute(builder: (_) => const FoldersScreen());

      case '/expenses':
        print('🧭 [Router] Building ExpensesScreen');
        return MaterialPageRoute(builder: (_) => const ExpensesScreen());

      case '/settings':
        print('🧭 [Router] Building SettingsScreen');
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      case '/capture-document':
        print('🧭 [Router] Building CaptureDocumentScreen');
        return MaterialPageRoute(builder: (_) => const CaptureDocumentScreen());

      case '/search':
        print('🧭 [Router] Building SearchScreen');
        return MaterialPageRoute(builder: (_) => const SearchScreen());

      case '/folder-details':
        final folderId = settings.arguments as String;
        print('🧭 [Router] Building FolderDetailsScreen for folder: $folderId');
        return MaterialPageRoute(
          builder: (_) => FolderDetailsScreen(folderId: folderId),
        );

      case '/document-details':
        final documentId = settings.arguments as String;
        print(
            '🧭 [Router] Building DocumentDetailsScreen for document: $documentId');
        return MaterialPageRoute(
          builder: (_) => DocumentDetailsScreen(documentId: documentId),
        );

      case '/notifications':
        print('🧭 [Router] Building NotificationsScreen');
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());

      case '/expense-analytics':
        print('🧭 [Router] Building ExpenseAnalyticsScreen');
        return MaterialPageRoute(
            builder: (_) => const ExpenseAnalyticsScreen());

      case '/documents':
        print('🧭 [Router] Redirecting /documents to FoldersScreen');
        // Redirect to folders screen
        return MaterialPageRoute(builder: (_) => const FoldersScreen());

      default:
        print('🧭 [Router] ERROR: No route defined for ${settings.name}');
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
