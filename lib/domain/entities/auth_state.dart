enum AuthorizationState {
  waitTdlibParameters,
  waitEncryptionKey,
  waitPhoneNumber,
  waitCode,
  waitOtherDeviceConfirmation,
  waitRegistration,
  waitPassword,
  ready,
  loggingOut,
  closing,
  closed,
  unknown,
}

class AuthenticationState {
  final AuthorizationState state;
  final Map<String, dynamic>? extra;
  final String? error;

  const AuthenticationState({required this.state, this.extra, this.error});

  factory AuthenticationState.fromJson(Map<String, dynamic> json) {
    final type = json['@type'] as String;

    AuthorizationState state;
    switch (type) {
      case 'authorizationStateWaitTdlibParameters':
        state = AuthorizationState.waitTdlibParameters;
        break;
      case 'authorizationStateWaitEncryptionKey':
        state = AuthorizationState.waitEncryptionKey;
        break;
      case 'authorizationStateWaitPhoneNumber':
        state = AuthorizationState.waitPhoneNumber;
        break;
      case 'authorizationStateWaitCode':
        state = AuthorizationState.waitCode;
        break;
      case 'authorizationStateWaitOtherDeviceConfirmation':
        state = AuthorizationState.waitOtherDeviceConfirmation;
        break;
      case 'authorizationStateWaitRegistration':
        state = AuthorizationState.waitRegistration;
        break;
      case 'authorizationStateWaitPassword':
        state = AuthorizationState.waitPassword;
        break;
      case 'authorizationStateReady':
        state = AuthorizationState.ready;
        break;
      case 'authorizationStateLoggingOut':
        state = AuthorizationState.loggingOut;
        break;
      case 'authorizationStateClosing':
        state = AuthorizationState.closing;
        break;
      case 'authorizationStateClosed':
        state = AuthorizationState.closed;
        break;
      default:
        state = AuthorizationState.unknown;
    }

    return AuthenticationState(state: state, extra: json);
  }

  @override
  String toString() {
    return 'AuthenticationState(state: $state, error: $error)';
  }
}

class CodeInfo {
  final String phoneNumber;
  final String type;
  final String nextType;
  final int timeout;

  const CodeInfo({
    required this.phoneNumber,
    required this.type,
    required this.nextType,
    required this.timeout,
  });

  factory CodeInfo.fromJson(Map<String, dynamic> json) {
    return CodeInfo(
      phoneNumber: json['phone_number'] ?? '',
      type: json['type']?['@type'] ?? '',
      nextType: json['next_type']?['@type'] ?? '',
      timeout: json['timeout'] ?? 0,
    );
  }
}

class QrCodeInfo {
  final String link;

  const QrCodeInfo({required this.link});

  factory QrCodeInfo.fromJson(Map<String, dynamic> json) {
    return QrCodeInfo(link: json['link'] ?? '');
  }
}
