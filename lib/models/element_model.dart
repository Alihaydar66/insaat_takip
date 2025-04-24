class ElementModel {
  final String id;
  final String name;
  final String floorId;
  final List<PhotoModel>? photos;
  final DateTime createdAt;

  ElementModel({
    required this.id,
    required this.name,
    required this.floorId,
    this.photos,
    required this.createdAt,
  });

  factory ElementModel.fromJson(Map<String, dynamic> json) {
    return ElementModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      floorId: json['floor_id'].toString(),
      photos: json['photos'] != null
          ? (json['photos'] as List).map((p) => PhotoModel.fromJson(p)).toList()
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
      'floor_id': floorId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ElementModel copyWith({
    String? id,
    String? name,
    String? floorId,
    List<PhotoModel>? photos,
    DateTime? createdAt,
  }) {
    return ElementModel(
      id: id ?? this.id,
      name: name ?? this.name,
      floorId: floorId ?? this.floorId,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PhotoModel {
  final String id;
  final String url;
  final String elementId;
  final DateTime uploadedAt;
  final bool approved;

  PhotoModel({
    required this.id,
    required this.url,
    required this.elementId,
    required this.uploadedAt,
    required this.approved,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'],
      url: json['url'],
      elementId: json['element_id'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
      approved: json['approved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'element_id': elementId,
      'uploaded_at': uploadedAt.toIso8601String(),
      'approved': approved,
    };
  }

  PhotoModel copyWith({
    String? id,
    String? url,
    String? elementId,
    DateTime? uploadedAt,
    bool? approved,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      url: url ?? this.url,
      elementId: elementId ?? this.elementId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      approved: approved ?? this.approved,
    );
  }
} 