import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/ui_constants.dart';
import '../presentation/providers/app_providers.dart';
import '../widgets/auth/phone_input_widget.dart';
import '../widgets/auth/code_input_widget.dart';
import '../widgets/auth/password_input_widget.dart';
import '../widgets/auth/registration_widget.dart';
import '../widgets/auth/qr_auth_widget.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.8),
              colorScheme.primary,
            ],
          ),
        ),
        child: Center(
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.all(Spacing.xxl),
            child: Container(
              width: AuthLayout.dialogWidth,
              height: AuthLayout.dialogHeight,
              padding: const EdgeInsets.all(Spacing.xxl),
              child: Column(
                children: [
                  // Header
                  Icon(
                    Icons.telegram,
                    size: IconSize.xl,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    'Telegram Flutter Client',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Sign in to your account',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(
                        alpha: Opacities.high,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.xxl),

                  // Tab Bar
                  TabBar(
                    controller: _tabController,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurface.withValues(
                      alpha: Opacities.high,
                    ),
                    indicatorColor: colorScheme.primary,
                    tabs: const [
                      Tab(icon: Icon(Icons.phone), text: 'Phone Number'),
                      Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
                    ],
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_buildPhoneAuthTab(), _buildQrAuthTab()],
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
    if (ref.needsPhoneNumber) {
      return const PhoneInputWidget();
    } else if (ref.needsCode) {
      return const CodeInputWidget();
    } else if (ref.needsPassword) {
      return const PasswordInputWidget();
    } else if (ref.needsRegistration) {
      return const RegistrationWidget();
    } else if (ref.isLoading) {
      return _buildLoadingState('Connecting to Telegram...');
    } else {
      return _buildSkeletonLoader();
    }
  }

  Widget _buildQrAuthTab() {
    return const QrAuthWidget();
  }

  Widget _buildLoadingState(String message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: Opacities.high),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Skeleton for input field
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Center(
              child: SizedBox(
                width: IconSize.sm,
                height: IconSize.sm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onSurface.withValues(alpha: Opacities.medium),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // Skeleton for button
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
          ),
          const SizedBox(height: Spacing.lg),

          // Loading text
          Text(
            'Initializing authentication...',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: Opacities.medium),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
