class UserModel {
  final String id;
  final String username;
  final String? email;
  final String? phone;
  final String? profession;
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.username,
    this.email,
    this.phone,
    this.profession,
    this.photoUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      username: json['username'] ?? '',
      email: json['email'],
      phone: json['phone'],
      profession: json['profession'],
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'profession': profession,
      'photo_url': photoUrl,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? phone,
    String? profession,
    String? photoUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profession: profession ?? this.profession,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
} 