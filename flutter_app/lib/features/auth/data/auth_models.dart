class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.credits,
    this.email,
    this.avatarUrl = '',
  });

  final int id;
  final String username;
  final String? email;
  final String role;
  final String avatarUrl;
  final int credits;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'user',
      avatarUrl: json['avatar_url'] as String? ?? '',
      credits: json['credits'] as int? ?? 0,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}
