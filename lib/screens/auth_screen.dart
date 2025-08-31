import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/app_providers.dart';
import '../widgets/auth/phone_input_widget.dart';
import '../widgets/auth/code_input_widget.dart';
import '../widgets/auth/password_input_widget.dart';
import '../widgets/auth/registration_widget.dart';
import '../widgets/auth/qr_auth_widget.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
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
    final authRepository = ref.watch(authenticationRepositoryProvider);

    if (authRepository.needsPhoneNumber) {
      return PhoneInputWidget();
    } else if (authRepository.needsCode) {
      return CodeInputWidget();
    } else if (authRepository.needsPassword) {
      return PasswordInputWidget();
    } else if (authRepository.needsRegistration) {
      return RegistrationWidget();
    } else if (authRepository.isLoading) {
      return _buildLoadingState('Connecting to Telegram...');
    } else {
      return _buildSkeletonLoader();
    }
  }

  Widget _buildQrAuthTab() {
    return QrAuthWidget();
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Skeleton for input field
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Skeleton for button
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),

          // Loading text
          const Text(
            'Initializing authentication...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
