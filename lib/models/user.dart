class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? profilePicture;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profilePicture,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromSupabase(Map<String, dynamic> data) {
    return User(
      id: data['id'] as String,
      name: data['name'] as String,
      email: data['email'] as String,
      role: data['role'] as String,
      profilePicture: data['profile_picture'] as String?,
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null 
          ? DateTime.parse(data['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'profile_picture': profilePicture,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? profilePicture,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      profilePicture: profilePicture ?? this.profilePicture,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}