import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/app_providers.dart';
import '../common/error_container.dart';
import '../common/loading_button.dart';

class CodeInputWidget extends ConsumerStatefulWidget {
  const CodeInputWidget({super.key});

  @override
  ConsumerState<CodeInputWidget> createState() => _CodeInputWidgetState();
}

class _CodeInputWidgetState extends ConsumerState<CodeInputWidget> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorMessage = ref.errorMessage;
    final isLoading = ref.isLoading;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.message,
              size: 32,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Enter verification code',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Code sent via Telegram',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Verification code',
                hintText: '12345',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter the verification code';
                }
                if (value!.length < 5) {
                  return 'Code should be at least 5 digits';
                }
                return null;
              },
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              ErrorContainer(message: errorMessage),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: isLoading ? null : _resendCode,
              child: Text(
                'Didn\'t receive the code? Resend',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),
            LoadingButton(
              label: 'Verify',
              onPressed: _submitCode,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }

  void _submitCode() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.clearError();
      ref.submitVerificationCode(_codeController.text.trim());
    }
  }

  void _resendCode() {
    ref.clearError();
    ref.resendCode();
  }
}
