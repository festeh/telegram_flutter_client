import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'presentation/providers/app_providers.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'core/logging/logging_config.dart';
import 'core/logging/tdlib_log_level.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize logging system with minimal TDLib logging
  await LoggingConfig.initialize(
    tdlibLogLevel: TdLibLogLevel.fatal, // Minimal C++ logging
  );

  runApp(
    const ProviderScope(
      child: TelegramFlutterApp(),
    ),
  );
}

class TelegramFlutterApp extends ConsumerWidget {
  const TelegramFlutterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Telegram Flutter Client',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      theme: AppTheme.dark,
      home: const AppWrapper(),
    );
  }
}

class AppWrapper extends ConsumerWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      data: (authState) {
        // Show appropriate screen based on auth state
        if (authState.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const AuthScreen();
        }
      },
      loading: () => MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.dark,
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Initializing Telegram Client...',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      height: 2,
                      child: LinearProgressIndicator(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      error: (error, stackTrace) => MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.dark,
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            final colorScheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.error,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to initialize app',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(authProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
