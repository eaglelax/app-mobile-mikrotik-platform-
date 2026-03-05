import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/site_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        themeMode: ThemeMode.dark,
        home: Consumer<AuthProvider>(
          builder: (ctx, auth, _) {
            if (auth.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (auth.isAuthenticated) {
              return const AppShell();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
