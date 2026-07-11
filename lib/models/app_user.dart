import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, worker }

enum ApprovalStatus { approved, pending, rejected }

class AppUser {
  final String id;
  final String organizationId;
  final String name;
  final String email;
  final UserRole role;
  final ApprovalStatus approvalStatus;

  const AppUser({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.email,
    required this.role,
    required this.approvalStatus,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      organizationId: data['organizationId'] as String,
      name: data['name'] as String,
      email: data['email'] as String,
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.worker,
      approvalStatus: _parseApprovalStatus(data['approvalStatus'] as String),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'name': name,
      'email': email,
      'role': role.name,
      'approvalStatus': approvalStatus.name,
    };
  }

  static ApprovalStatus _parseApprovalStatus(String value) {
    switch (value) {
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      default:
        return ApprovalStatus.pending;
    }
  }

  AppUser copyWith({ApprovalStatus? approvalStatus}) {
    return AppUser(
      id: id,
      organizationId: organizationId,
      name: name,
      email: email,
      role: role,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }
}
