import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth_manager.dart';
import '../widgets/auth_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.all(32),
            child: Container(
              width: 450,
              height: 600,
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Header
                  Icon(
                    Icons.telegram,
                    size: 64,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Telegram Flutter Client',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your account',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Tab Bar
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue.shade600,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: Colors.blue.shade600,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.phone),
                        text: 'Phone Number',
                      ),
                      Tab(
                        icon: Icon(Icons.qr_code),
                        text: 'QR Code',
                      ),
                    ],
                  ),
                  
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPhoneAuthTab(),
                        _buildQrAuthTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPhoneAuthTab() {
    return Consumer<AuthManager>(
      builder: (context, authManager, child) {
        if (authManager.needsPhoneNumber) {
          return PhoneInputWidget();
        } else if (authManager.needsCode) {
          return CodeInputWidget();
        } else if (authManager.needsPassword) {
          return PasswordInputWidget();
        } else if (authManager.needsRegistration) {
          return RegistrationWidget();
        } else if (authManager.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Connecting to Telegram...'),
              ],
            ),
          );
        } else {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Initializing...'),
              ],
            ),
          );
        }
      },
    );
  }
  
  Widget _buildQrAuthTab() {
    return Consumer<AuthManager>(
      builder: (context, authManager, child) {
        return QrAuthWidget();
      },
    );
  }
}