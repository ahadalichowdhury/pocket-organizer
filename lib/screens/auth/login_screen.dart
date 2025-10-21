import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/services/document_sync_service.dart';
import '../../data/services/expense_sync_service.dart';
import '../../data/services/folder_sync_service.dart';
import '../../data/services/hive_service.dart';
import '../../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _canCheckBiometrics = false;
  bool _hasSavedCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _checkSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck || isDeviceSupported;
        });
      }
    } catch (e) {
      print('Error checking biometrics: $e');
    }
  }

  Future<void> _checkSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: 'saved_email');
      if (mounted) {
        setState(() {
          _hasSavedCredentials = email != null;
        });
      }
    } catch (e) {
      print('Error checking saved credentials: $e');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      setState(() => _isLoading = true);

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        // Get stored credentials
        final email = await _secureStorage.read(key: 'saved_email');
        final password = await _secureStorage.read(key: 'saved_password');

        if (email != null && password != null) {
          _emailController.text = email;
          _passwordController.text = password;
          await _handleLogin(skipBiometricPrompt: true);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('No saved credentials found. Please login manually.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin({bool skipBiometricPrompt = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // Try Firebase first, fallback to local auth
    final authService = ref.read(authServiceProvider);
    var result = await authService.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    // If Firebase fails, try local auth
    if (!result['success']) {
      print('Firebase login failed, trying local auth...');
      final localAuth = ref.read(localAuthServiceProvider);
      await localAuth.init();
      result = await localAuth.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success']) {
      print('🔐 [Login] Login successful');

      // Get user ID
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        print('❌ [Login] No user ID found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login error: No user ID'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Open user-specific Hive boxes
      print('🔐 [Login] Opening user-specific storage for: $userId');
      try {
        await HiveService.openUserBoxes(userId);
        print('🔐 [Login] ✅ User storage opened');

        // Download data from MongoDB
        print('🔐 [Login] Downloading data from MongoDB...');
        final foldersFuture = FolderSyncService.downloadFoldersFromMongoDB();
        final documentsFuture =
            DocumentSyncService.downloadDocumentsFromMongoDB();
        final expenseFuture =
            ExpenseSyncService().downloadExpensesFromMongoDB();

        final results =
            await Future.wait([foldersFuture, documentsFuture, expenseFuture]);

        // Save downloaded data to local Hive
        for (final folder in results[0] as List) {
          await HiveService.addFolder(folder);
        }
        for (final document in results[1] as List) {
          await HiveService.addDocument(document);
        }
        // Expenses are already saved in downloadExpensesFromMongoDB

        print(
            '🔐 [Login] ✅ Downloaded ${(results[0] as List).length} folders, ${(results[1] as List).length} documents');
      } catch (e) {
        print('🔐 [Login] ⚠️ Failed to open user storage or download: $e');
      }

      // Refresh UI providers (will load from user-specific boxes)
      ref.read(foldersProvider.notifier).loadFolders();
      ref.read(documentsProvider.notifier).loadDocuments();
      ref.read(expensesProvider.notifier).loadExpenses();

      print('🔐 [Login] ✅ User data loaded from local storage');

      // Check if user has already been prompted for biometric setup
      final hasBeenPrompted =
          HiveService.getSetting('biometric_prompt_shown', defaultValue: false)
              as bool;
      print('🔐 [Login] Has been prompted for biometric: $hasBeenPrompted');
      print('🔐 [Login] Skip biometric prompt: $skipBiometricPrompt');
      print('🔐 [Login] Can check biometrics: $_canCheckBiometrics');
      print('🔐 [Login] Has saved credentials: $_hasSavedCredentials');

      // Prompt to enable biometric login if not already enabled AND hasn't been prompted before
      if (!skipBiometricPrompt &&
          _canCheckBiometrics &&
          !_hasSavedCredentials &&
          !hasBeenPrompted) {
        print('🔐 [Login] Showing biometric setup prompt');
        // Save that we've shown the prompt
        await HiveService.saveSetting('biometric_prompt_shown', true);
        _promptBiometricSetup();
      } else {
        print('🔐 [Login] Navigating to /home');
        // Navigate to home
        if (mounted) {
          print('🔐 [Login] Widget is mounted, pushing to /home');
          Navigator.of(context).pushReplacementNamed('/home');
          print('🔐 [Login] Navigation complete');
        } else {
          print('🔐 [Login] WARNING: Widget not mounted, skipping navigation');
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _promptBiometricSetup() async {
    final enable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: Colors.blue),
            SizedBox(width: 12),
            Text('Enable Biometric Login?'),
          ],
        ),
        content: const Text(
          'Would you like to use fingerprint or face recognition to login faster next time?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Enable'),
          ),
        ],
      ),
    );

    if (enable == true) {
      // Save credentials securely
      await _secureStorage.write(
          key: 'saved_email', value: _emailController.text.trim());
      await _secureStorage.write(
          key: 'saved_password', value: _passwordController.text);

      if (mounted) {
        setState(() => _hasSavedCredentials = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Biometric login enabled!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon
                  Icon(
                    Icons.folder_special,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Pocket Organizer',
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Organize your documents & expenses',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot-password');
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Log In'),
                  ),

                  // Biometric Login Button
                  if (_canCheckBiometrics && _hasSavedCredentials)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: OutlinedButton.icon(
                        onPressed:
                            _isLoading ? null : _authenticateWithBiometrics,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Login with Biometrics'),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
