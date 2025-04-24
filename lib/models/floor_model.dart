class FloorModel {
  final String id;
  final String name;
  final String projectId;
  final DateTime createdAt;

  FloorModel({
    required this.id,
    required this.name,
    required this.projectId,
    required this.createdAt,
  });

  factory FloorModel.fromJson(Map<String, dynamic> json) {
    return FloorModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      projectId: json['project_id'].toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'project_id': projectId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  FloorModel copyWith({
    String? id,
    String? name,
    String? projectId,
    DateTime? createdAt,
  }) {
    return FloorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 