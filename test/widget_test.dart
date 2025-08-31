import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_flutter_client/core/auth_manager.dart';
import 'package:telegram_flutter_client/core/tdlib_client.dart';
import 'package:telegram_flutter_client/models/auth_state.dart';
import 'package:telegram_flutter_client/models/user_session.dart';

void main() {
  group('Models', () {
    test('AuthenticationState should be created correctly', () {
      final authState = AuthenticationState.fromJson({
        '@type': 'authorizationStateWaitPhoneNumber',
      });

      expect(authState.state, AuthorizationState.waitPhoneNumber);
    });

    test('UserSession should be created correctly', () {
      final session = UserSession.fromJson({
        'id': 123456789,
        'first_name': 'John',
        'last_name': 'Doe',
        'username': 'johndoe',
        'phone_number': '+1234567890',
        'is_authorized': true,
      });

      expect(session.userId, 123456789);
      expect(session.firstName, 'John');
      expect(session.lastName, 'Doe');
      expect(session.username, 'johndoe');
      expect(session.phoneNumber, '+1234567890');
      expect(session.isAuthorized, true);
      expect(session.displayName, 'John Doe');
    });

    test('CodeInfo should be created correctly', () {
      final codeInfo = CodeInfo.fromJson({
        'phone_number': '+1234567890',
        'type': {'@type': 'authenticationCodeTypeSms'},
        'next_type': {'@type': 'authenticationCodeTypeCall'},
        'timeout': 60,
      });

      expect(codeInfo.phoneNumber, '+1234567890');
      expect(codeInfo.type, 'authenticationCodeTypeSms');
      expect(codeInfo.nextType, 'authenticationCodeTypeCall');
      expect(codeInfo.timeout, 60);
    });
  });

  group('TelegramClient', () {
    test('should create client instance', () {
      final client = TelegramClient();
      expect(client, isNotNull);
      expect(client.currentAuthState.state, AuthorizationState.unknown);
    });
  });
}
