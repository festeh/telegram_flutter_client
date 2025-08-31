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
  late TelegramClient _client;
  late AuthManager _authManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      _client = TelegramClient();
      _authManager = AuthManager(_client);
      
      await _authManager.initialize();
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Failed to initialize app: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _authManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing Telegram Client...'),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<AuthManager>.value(
      value: _authManager,
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
  }
}