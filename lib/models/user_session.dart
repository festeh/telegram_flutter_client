class UserSession {
  final int userId;
  final String firstName;
  final String lastName;
  final String username;
  final String phoneNumber;
  final bool isAuthorized;
  
  const UserSession({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.phoneNumber,
    required this.isAuthorized,
  });
  
  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      isAuthorized: json['is_authorized'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'phone_number': phoneNumber,
      'is_authorized': isAuthorized,
    };
  }
  
  String get displayName {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (username.isNotEmpty) {
      return '@$username';
    } else {
      return phoneNumber;
    }
  }
  
  @override
  String toString() {
    return 'UserSession(userId: $userId, displayName: $displayName, username: $username)';
  }
}