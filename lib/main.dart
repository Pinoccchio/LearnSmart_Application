import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const LearnSmartApp());
}

class LearnSmartApp extends StatefulWidget {
  const LearnSmartApp({super.key});

  @override
  State<LearnSmartApp> createState() => _LearnSmartAppState();
}

class _LearnSmartAppState extends State<LearnSmartApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      print('❌ [DEEP LINK] Error handling deep link: $err');
    });

    // Handle initial link if app was opened via deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('❌ [DEEP LINK] Error getting initial link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    print('🔗 [DEEP LINK] Received: $uri');

    // Check if this is a password reset link
    if (uri.scheme == 'io.supabase.learnsmart' && uri.host == 'reset-password') {
      print('🔑 [DEEP LINK] Password reset link detected');

      // Navigate to reset password screen
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const ResetPasswordScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'LearnSmart',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}