import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  final String id;
  final String organizationId;
  final String actorId;
  final String actorName;
  final String actionType;
  final String? jobId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const AuditLogEntry({
    required this.id,
    required this.organizationId,
    required this.actorId,
    required this.actorName,
    required this.actionType,
    required this.timestamp,
    this.jobId,
    this.metadata,
  });

  factory AuditLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLogEntry(
      id: doc.id,
      organizationId: data['organizationId'] as String,
      actorId: data['actorId'] as String,
      actorName: data['actorName'] as String,
      actionType: data['actionType'] as String,
      jobId: data['jobId'] as String?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'actorId': actorId,
      'actorName': actorName,
      'actionType': actionType,
      'jobId': jobId,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}
