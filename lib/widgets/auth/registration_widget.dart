import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/app_providers.dart';
import '../common/error_container.dart';
import '../common/loading_button.dart';

class RegistrationWidget extends ConsumerStatefulWidget {
  const RegistrationWidget({super.key});

  @override
  ConsumerState<RegistrationWidget> createState() => _RegistrationWidgetState();
}

class _RegistrationWidgetState extends ConsumerState<RegistrationWidget> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorMessage = ref.errorMessage;
    final isLoading = ref.isLoading;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Create your profile',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your name to complete registration',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'First name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Last name (optional)',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorContainer(
                message: errorMessage,
                padding: const EdgeInsets.all(12),
                borderRadius: 8,
              ),
            ],
            const SizedBox(height: 32),
            LoadingButton(
              label: 'Register',
              onPressed: _submitRegistration,
              isLoading: isLoading,
              height: 50,
            ),
          ],
        ),
      ),
    );
  }

  void _submitRegistration() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.clearError();
      ref.registerUser(
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
      );
    }
  }
}
