import '../../../core/models/enums.dart';
import '../../../core/time/json_time.dart';

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    this.incidentRetentionDays = 30,
  });

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final int incidentRetentionDays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'createdAt': writeTime(createdAt),
        'incidentRetentionDays': incidentRetentionDays,
      };

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      createdAt: parseTime(json['createdAt']),
      incidentRetentionDays: (json['incidentRetentionDays'] as num?)?.toInt() ?? 30,
    );
  }

  Organization copyWith({String? name, int? incidentRetentionDays}) {
    return Organization(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      createdAt: createdAt,
      incidentRetentionDays: incidentRetentionDays ?? this.incidentRetentionDays,
    );
  }
}

class OrganizationMember {
  const OrganizationMember({
    required this.userId,
    required this.organizationId,
    required this.role,
    required this.createdAt,
    this.email = '',
  });

  final String userId;
  final String organizationId;
  final MemberRole role;
  final DateTime createdAt;
  final String email;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'organizationId': organizationId,
        'role': role.name,
        'createdAt': writeTime(createdAt),
        'email': email,
      };

  factory OrganizationMember.fromJson(Map<String, dynamic> json) {
    return OrganizationMember(
      userId: json['userId'] as String,
      organizationId: json['organizationId'] as String,
      role: enumByName(MemberRole.values, json['role'], MemberRole.viewer),
      createdAt: parseTime(json['createdAt']),
      email: json['email'] as String? ?? '',
    );
  }
}
