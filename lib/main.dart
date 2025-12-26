import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'presentation/providers/app_providers.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'core/logging/logging_config.dart';
import 'core/logging/tdlib_log_level.dart';
import 'core/theme/app_theme.dart';

const _loadingPhrases = [
  'Warming up the hamster wheel...',
  'Convincing electrons to cooperate...',
  'Brewing some digital coffee...',
  'Untangling the internet cables...',
  'Asking servers nicely...',
  'Reticulating splines...',
  'Charging the flux capacitor...',
  'Feeding the code monkeys...',
  'Polishing the pixels...',
  'Summoning the wifi spirits...',
  'Teaching bits to dance...',
  'Waking up the cloud...',
];

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
  const TelegramFlutterApp({super.key});

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
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      data: (authState) {
        // Show appropriate screen based on auth state
        if (authState.isAuthenticated) {
          // Also wait for chats to be loaded before showing home screen
          final chatAsync = ref.watch(chatProvider);
          return chatAsync.when(
            data: (chatState) {
              // Only show home screen when chats are initialized
              if (chatState.isInitialized) {
                return const HomeScreen();
              }
              return _buildLoadingScreen();
            },
            loading: () => _buildLoadingScreen(),
            error: (_, _) => const HomeScreen(), // Show home on chat error, let it handle retry
          );
        } else if (!authState.isInitialized) {
          // Still determining auth status - show loading
          return _buildLoadingScreen();
        } else {
          return const AuthScreen();
        }
      },
      loading: () => _buildLoadingScreen(),
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

  Widget _buildLoadingScreen() {
    final phrase = _loadingPhrases[Random().nextInt(_loadingPhrases.length)];
    return MaterialApp(
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
                    phrase,
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
    );
  }
}
