class ProjectModel {
  final String id;
  final String name;
  final String? companyName;
  final String? address;
  final String ownerId;
  final List<String>? memberIds;
  final DateTime createdAt;

  ProjectModel({
    required this.id,
    required this.name,
    this.companyName,
    this.address,
    required this.ownerId,
    this.memberIds,
    required this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      companyName: json['company_name'],
      address: json['address'],
      ownerId: json['owner_id'].toString(),
      memberIds: json['member_ids'] != null
          ? List<String>.from(json['member_ids'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company_name': companyName,
      'address': address,
      'owner_id': ownerId,
      'member_ids': memberIds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ProjectModel copyWith({
    String? id,
    String? name,
    String? companyName,
    String? address,
    String? ownerId,
    List<String>? memberIds,
    DateTime? createdAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 