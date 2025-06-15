class FloorModel {
  final String id;
  final String name;
  final String projectId;
  final int floorNumber;
  final DateTime createdAt;

  FloorModel({
    required this.id,
    required this.name,
    required this.projectId,
    this.floorNumber = 0,
    required this.createdAt,
  });

  factory FloorModel.fromJson(Map<String, dynamic> json) {
    return FloorModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      projectId: json['project_id'].toString(),
      floorNumber: json['floor_number'] != null ? int.parse(json['floor_number'].toString()) : 0,
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
      'floor_number': floorNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  FloorModel copyWith({
    String? id,
    String? name,
    String? projectId,
    int? floorNumber,
    DateTime? createdAt,
  }) {
    return FloorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      floorNumber: floorNumber ?? this.floorNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 