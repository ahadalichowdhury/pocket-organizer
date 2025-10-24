import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/automated_report_service.dart';
import 'data/services/budget_monitor_service.dart';
import 'data/services/connectivity_monitor_service.dart';
import 'data/services/fcm_service.dart';
import 'data/services/hive_service.dart';
import 'data/services/mongodb_service.dart';
import 'data/services/native_network_service.dart';
import 'data/services/s3_storage_service.dart';
import 'data/services/smart_sync_service.dart';
import 'data/services/user_settings_sync_service.dart';
import 'data/services/user_sync_service.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/folders/folders_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isInitialized = false;
  String _initStatus = 'Initializing...';
  bool _userBoxesReady = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Load environment variables
      setState(() => _initStatus = 'Loading configuration...');
      try {
        await dotenv.load(fileName: '.env');
        print('✅ Environment variables loaded');
      } catch (e) {
        print('⚠️ Failed to load .env file: $e');
        print('   App will work with default configuration');
      }

      // Initialize Firebase (only for auth and FCM notifications)
      setState(() => _initStatus = 'Connecting to Firebase...');
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('✅ Firebase initialized (Auth & FCM)');

        // Initialize FCM (Firebase Cloud Messaging)
        await FCMService.initialize();
        print('✅ FCM service initialized');
      } catch (e) {
        print('⚠️ Firebase initialization failed: $e');
        print('   Run: flutterfire configure');
      }

      // Initialize Hive Database (local storage)
      setState(() => _initStatus = 'Setting up local database...');
      await HiveService.init();
      print('✅ Hive database initialized');

      // Initialize MongoDB (cloud database - replaces Firestore)
      setState(() => _initStatus = 'Connecting to cloud storage...');
      await MongoDBService.init();
      if (MongoDBService.isConnected) {
        print('✅ MongoDB connected - cloud sync enabled');

        // Note: User creation/update is now handled in login/signup/main _initializeUserData
        // This ensures user document and FCM token are synced after authentication

        // Initialize Smart Sync Service (handles offline queue & auto-sync)
        setState(() => _initStatus = 'Setting up smart sync...');
        await SmartSyncService.initialize();
        print('✅ Smart sync initialized - automatic background sync enabled');
      } else {
        print('ℹ️ MongoDB not connected - working in local-only mode');
      }

      // Initialize AWS S3 (cloud storage - replaces Firebase Storage)
      setState(() => _initStatus = 'Setting up AWS S3...');
      await S3StorageService.init();
      if (S3StorageService.isConfigured) {
        print('✅ AWS S3 configured - cloud image storage enabled');
      } else {
        print('ℹ️ AWS S3 not configured - using local image storage only');
      }

      // Initialize automated reports (background tasks)
      setState(() => _initStatus = 'Setting up automated reports...');
      await AutomatedReportService.initialize();
      print('✅ Automated reports service initialized');

      // Initialize budget monitoring (background alerts)
      setState(() => _initStatus = 'Setting up budget monitoring...');
      await BudgetMonitorService.initialize();
      print('✅ Budget monitoring service initialized');

      // Initialize native network monitoring (like WhatsApp)
      setState(() => _initStatus = 'Setting up native network monitoring...');
      await NativeNetworkService.initialize();
      print('✅ Native network monitoring initialized');

      // Note: Foreground service removed - AlarmManager handles scheduled backups
      // No persistent "monitoring" notification needed anymore!

      setState(() {
        _initStatus = 'Ready!';
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Initialization error: $e');
      setState(() {
        _initStatus = 'Initialization complete';
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen while initializing
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(statusMessage: _initStatus),
      );
    }

    final isDarkMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Pocket Organizer',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // Routing
      onGenerateRoute: AppRouter.generateRoute,

      // Initial route based on auth state
      home: authState.when(
        data: (user) {
          if (user != null) {
            // Check if we need to initialize user data
            if (_currentUserId != user.uid) {
              _currentUserId = user.uid;
              _userBoxesReady = false;
              _initializeUserData(ref, user.uid);
            }

            // Only show AppHome when boxes are ready
            if (_userBoxesReady) {
              return const AppHome();
            } else {
              return SplashScreen(statusMessage: 'Loading your data...');
            }
          } else {
            // User not logged in, reset state
            _currentUserId = null;
            _userBoxesReady = false;
            return _checkFirstLaunch(ref);
          }
        },
        loading: () => SplashScreen(statusMessage: _initStatus),
        error: (error, stack) => ErrorScreen(error: error.toString()),
      ),
    );
  }

  Widget _checkFirstLaunch(WidgetRef ref) {
    // Check if user has seen onboarding before
    final hasSeenOnboarding =
        HiveService.getSetting('has_seen_onboarding', defaultValue: false);

    if (hasSeenOnboarding) {
      return const LoginScreen();
    } else {
      HiveService.saveSetting('has_seen_onboarding', true);
      return const OnboardingScreen();
    }
  }

  void _initializeUserData(WidgetRef ref, String userId) {
    // Open user-specific boxes and initialize data
    Future.microtask(() async {
      try {
        print('🔐 [Main] Opening user boxes for: $userId');
        await HiveService.openUserBoxes(userId);

        print('🔐 [Main] Syncing user settings...');
        final userSettings =
            await UserSettingsSyncService.syncSettingsOnLogin(userId);

        // Apply dark mode setting
        ref
            .read(themeModeProvider.notifier)
            .setDarkMode(userSettings.isDarkMode);

        // 🔧 FIX: Create/update user in MongoDB and sync FCM token
        print('🔐 [Main] Creating/updating user in MongoDB...');
        try {
          final authService = ref.read(authServiceProvider);
          final user = authService.currentUser;

          if (user != null) {
            // Create or update user document
            await UserSyncService.createOrUpdateUser(
              userId: user.uid,
              email: user.email ?? '',
              displayName: user.displayName,
              photoUrl: user.photoURL,
            );
            print('✅ [Main] User created/updated in MongoDB');

            // Sync FCM token to MongoDB
            print('🔐 [Main] Syncing FCM token to MongoDB...');
            await FCMService.syncTokenToMongoDB();
            print('✅ [Main] FCM token synced to MongoDB');
          }
        } catch (e) {
          print('⚠️ [Main] Failed to sync user/FCM to MongoDB: $e');
          // Don't block app initialization if this fails
        }

        // Schedule auto-sync if enabled
        final autoSyncInterval =
            HiveService.getSetting('auto_sync_interval', defaultValue: 'manual')
                as String;
        if (autoSyncInterval != 'manual') {
          print('🔄 [Main] Scheduling auto-sync: $autoSyncInterval');
          await AutomatedReportService.scheduleAutoSync(autoSyncInterval);
        }

        // Start connectivity monitoring for smart retry
        print('📡 [Main] Starting connectivity monitoring...');
        ConnectivityMonitorService.startMonitoring();

        // Start budget monitoring for background alerts
        print('📊 [Main] Starting budget monitoring...');
        await BudgetMonitorService.startMonitoring();

        print('🔐 [Main] Initializing default folders...');
        await ref.read(foldersProvider.notifier).initializeDefaultFolders();
        ref.read(documentsProvider.notifier).loadDocuments();
        ref.read(expensesProvider.notifier).loadExpenses();
        print('🔐 [Main] ✅ User data initialized');

        // Mark boxes as ready and trigger rebuild
        setState(() {
          _userBoxesReady = true;
        });
      } catch (e) {
        print('❌ [Main] Error initializing user data: $e');
        // Still mark as ready to show the app (data will be empty)
        setState(() {
          _userBoxesReady = true;
        });
      }
    });
  }
}

// App Home with Bottom Navigation
class AppHome extends ConsumerStatefulWidget {
  const AppHome({super.key});

  @override
  ConsumerState<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<AppHome> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    FoldersScreen(),
    ExpensesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    print('🏠 [AppHome] initState called');
    WidgetsBinding.instance.addObserver(this);

    // Log after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🏠 [AppHome] Post frame callback - Widget tree built');
      print('🏠 [AppHome] Current index: $_currentIndex');
      print('🏠 [AppHome] Mounted: $mounted');
      print('🏠 [AppHome] Context: ${context.mounted}');

      // Check SafeArea bottom insets
      final mediaQuery = MediaQuery.of(context);
      print('🏠 [AppHome] Bottom padding: ${mediaQuery.padding.bottom}');
      print('🏠 [AppHome] ViewInsets bottom: ${mediaQuery.viewInsets.bottom}');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🏠 [AppHome] App lifecycle changed: $state');

    // When app comes to foreground, check for pending reports and sync
    if (state == AppLifecycleState.resumed) {
      print('🏠 [AppHome] App resumed - checking for pending tasks...');
      _handleAppResume();
    }
  }

  /// Handle app resume - check for pending reports and trigger sync if needed
  Future<void> _handleAppResume() async {
    try {
      // Process any pending email reports
      print('📧 [AppHome] Processing pending email reports...');
      await AutomatedReportService.processPendingReports();
    } catch (e) {
      print('❌ [AppHome] Error processing pending reports: $e');
    }
  }

  @override
  void dispose() {
    print('🏠 [AppHome] dispose called');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🏠 [AppHome] build() called - currentIndex: $_currentIndex');

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          print('🏠 [AppHome] BottomNavigationBar builder called');
          final mediaQuery = MediaQuery.of(context);
          print(
              '🏠 [AppHome] MediaQuery padding bottom: ${mediaQuery.padding.bottom}');

          return Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 8),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  print('🏠 [AppHome] Bottom nav tapped: $index');
                  setState(() => _currentIndex = index);
                },
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.folder_outlined),
                    activeIcon: Icon(Icons.folder),
                    label: 'Folders',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    activeIcon: Icon(Icons.account_balance_wallet),
                    label: 'Expenses',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Splash Screen
class SplashScreen extends StatelessWidget {
  final String statusMessage;

  const SplashScreen({super.key, this.statusMessage = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.folder_special,
                size: 70,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            const Text(
              'Pocket Organizer',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              'Your Personal Finance & Document Manager',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 48),

            // Loading Indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 24),

            // Status Message
            Text(
              statusMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Error Screen
class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Restart app or navigate to login
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
