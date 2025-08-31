import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/tdlib_client.dart';
import 'core/auth_manager.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TelegramFlutterApp());
}

class TelegramFlutterApp extends StatelessWidget {
  const TelegramFlutterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram Flutter Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AppWrapper(),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({Key? key}) : super(key: key);

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  late Future<AuthManager> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeApp();
  }

  Future<AuthManager> _initializeApp() async {
    try {
      final client = TelegramClient();
      final authManager = AuthManager(client);
      
      await authManager.initialize();
      
      return authManager;
    } catch (e) {
      print('Failed to initialize app: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _initializationFuture.then((authManager) => authManager.dispose()).catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthManager>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Initializing Telegram Client...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 200,
                      height: 2,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to initialize app',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initializationFuture = _initializeApp();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final authManager = snapshot.data!;
        return ChangeNotifierProvider<AuthManager>.value(
          value: authManager,
          child: Consumer<AuthManager>(
            builder: (context, authManager, child) {
              if (authManager.isAuthenticated) {
                return const HomeScreen();
              } else {
                return const AuthScreen();
              }
            },
          ),
        );
      },
    );
  }
}