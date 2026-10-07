/// The signed-in account.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.type = 'user',
    this.emailVerified = true,
  });

  final String id;
  final String email;
  final String? name;
  final String type;

  /// Whether the email address was confirmed (trial credits and buying
  /// credits wait for it).
  final bool emailVerified;

  /// Name when set, otherwise the email address.
  String get displayName => (name != null && name!.trim().isNotEmpty) ? name!.trim() : email;

  AppUser copyWith({bool? emailVerified}) => AppUser(
        id: id,
        email: email,
        name: name,
        type: type,
        emailVerified: emailVerified ?? this.emailVerified,
      );
}

/// A signed-in session: the account and its bearer token.
class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AppUser user;
  final String token;
}
