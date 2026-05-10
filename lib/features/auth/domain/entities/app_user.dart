class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    this.email,
    this.isAdmin = false,
  });

  final String id;
  final String fullName;
  final String? email;
  final bool isAdmin;
}
