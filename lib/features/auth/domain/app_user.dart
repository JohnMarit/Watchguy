class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final String? photoUrl;

  AppUser copyWith({bool? emailVerified, String? displayName}) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
      photoUrl: photoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'emailVerified': emailVerified,
        'photoUrl': photoUrl,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      emailVerified: json['emailVerified'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
