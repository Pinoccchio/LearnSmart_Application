class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? profilePicture;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profilePicture,
  });
}