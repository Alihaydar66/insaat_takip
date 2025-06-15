class ProjectModel {
  final String id;
  final String name;
  final String? companyName;
  final String? address;
  final String ownerId;
  final List<String>? memberIds;
  final List<String>? authorizedMemberIds;
  final DateTime createdAt;

  ProjectModel({
    required this.id,
    required this.name,
    this.companyName,
    this.address,
    required this.ownerId,
    this.memberIds,
    this.authorizedMemberIds,
    required this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    List<String>? memberIdsList;
    List<String>? authorizedMemberIdsList;
    
    // member_ids işleme
    if (json['member_ids'] != null) {
      if (json['member_ids'] is List) {
        memberIdsList = List<String>.from(json['member_ids'].map((id) => id.toString()));
      } else if (json['member_ids'] is String) {
        // String formatı "[id1, id2, id3]" şeklindeyse
        String memberIdsStr = json['member_ids'].toString();
        memberIdsStr = memberIdsStr.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
        if (memberIdsStr.isNotEmpty) {
          memberIdsList = memberIdsStr.split(',').map((e) => e.trim()).toList();
        } else {
          memberIdsList = [];
        }
      }
    }
    
    // authorized_member_ids işleme
    if (json['authorized_member_ids'] != null) {
      if (json['authorized_member_ids'] is List) {
        authorizedMemberIdsList = List<String>.from(json['authorized_member_ids'].map((id) => id.toString()));
      } else if (json['authorized_member_ids'] is String) {
        // String formatı "[id1, id2, id3]" şeklindeyse
        String authorizedStr = json['authorized_member_ids'].toString();
        authorizedStr = authorizedStr.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
        if (authorizedStr.isNotEmpty) {
          authorizedMemberIdsList = authorizedStr.split(',').map((e) => e.trim()).toList();
        } else {
          authorizedMemberIdsList = [];
        }
      }
    }
    
    return ProjectModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      companyName: json['company_name'],
      address: json['address'],
      ownerId: json['owner_id'].toString(),
      memberIds: memberIdsList,
      authorizedMemberIds: authorizedMemberIdsList,
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
      'member_ids': memberIds ?? [],
      'authorized_member_ids': authorizedMemberIds ?? [],
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
    List<String>? authorizedMemberIds,
    DateTime? createdAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      authorizedMemberIds: authorizedMemberIds ?? this.authorizedMemberIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 