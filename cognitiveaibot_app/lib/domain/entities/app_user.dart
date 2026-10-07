/// The signed-in account.
class AppUser {
  const AppUser({required this.id, required this.email, this.name, this.type = 'user'});

  final String id;
  final String email;
  final String? name;
  final String type;

  /// Name when set, otherwise the email address.
  String get displayName => (name != null && name!.trim().isNotEmpty) ? name!.trim() : email;
}

/// A signed-in session: the account and its bearer token.
class AuthSession {
  const AuthSession({required this.user, required this.token});

  final AppUser user;
  final String token;
}
