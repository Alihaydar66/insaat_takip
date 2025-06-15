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
  final bool? approved;
  final String? localPath;

  PhotoModel({
    required this.id,
    required this.url,
    required this.elementId,
    required this.uploadedAt,
    this.approved,
    this.localPath,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'],
      url: json['url'] ?? '',
      elementId: json['element_id'],
      uploadedAt: json['uploaded_at'] != null 
          ? DateTime.parse(json['uploaded_at']) 
          : (json['created_at'] != null 
              ? DateTime.parse(json['created_at']) 
              : DateTime.now()),
      approved: json['approved'] ?? 
          (json['status'] == 'approved' 
              ? true 
              : (json['status'] == 'rejected' ? false : null)),
      localPath: json['local_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'element_id': elementId,
      'uploaded_at': uploadedAt.toIso8601String(),
      'status': approved == null 
          ? 'pending' 
          : (approved == true ? 'approved' : 'rejected'),
      'local_path': localPath,
    };
  }

  PhotoModel copyWith({
    String? id,
    String? url,
    String? elementId,
    DateTime? uploadedAt,
    bool? approved,
    String? localPath,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      url: url ?? this.url,
      elementId: elementId ?? this.elementId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      approved: approved ?? this.approved,
      localPath: localPath ?? this.localPath,
    );
  }
} 