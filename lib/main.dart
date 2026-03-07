import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/site_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pin_screen.dart';
import 'widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MikroTikApp());
}

class MikroTikApp extends StatelessWidget {
  const MikroTikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProxyProvider<AuthProvider, SiteProvider>(
          create: (_) => SiteProvider(),
          update: (_, auth, sites) => sites!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notif) => notif!..updateAuth(auth),
        ),
      ],
      child: MaterialApp(
        title: 'MikroTik Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (ctx, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not logged in → login screen
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        // Just logged in, no PIN set yet → PIN setup
        if (auth.needsPinSetup) {
          return _PinSetupGate(auth: auth);
        }

        // Has PIN but not yet verified this session → PIN entry
        if (auth.hasPin && !auth.pinVerified) {
          return _PinEntryGate(auth: auth);
        }

        // All good → main app
        return const AppShell();
      },
    );
  }
}

class _PinSetupGate extends StatelessWidget {
  final AuthProvider auth;
  const _PinSetupGate({required this.auth});

  @override
  Widget build(BuildContext context) {
    return PinScreen(
      isSetup: true,
      key: const ValueKey('pin-setup'),
    );
  }
}

class _PinEntryGate extends StatelessWidget {
  final AuthProvider auth;
  const _PinEntryGate({required this.auth});

  @override
  Widget build(BuildContext context) {
    return PinScreen(
      isSetup: false,
      key: const ValueKey('pin-entry'),
    );
  }
}
