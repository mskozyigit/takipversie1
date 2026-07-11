import 'package:cloud_firestore/cloud_firestore.dart';

enum JobStatus {
  notStarted,
  inProgress,
  workCompleted,
  closed,
}

class Job {
  final String id;
  final String organizationId;
  final String title;
  final String description;
  final String assignedWorkerId;
  final String assignedWorkerName;
  final String address;
  final DateTime scheduledDate;
  final JobStatus status;
  final String? missionNumber;
  final String? beforePhotoUrl;
  final String? afterPhotoUrl;
  final List<Map<String, dynamic>>? usedParts;
  final String? paymentMethod; // 'qr' or 'cash'
  final bool isPaid;
  final DateTime createdDate;

  const Job({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.assignedWorkerId,
    required this.assignedWorkerName,
    required this.address,
    required this.scheduledDate,
    required this.status,
    required this.createdDate,
    this.missionNumber,
    this.beforePhotoUrl,
    this.afterPhotoUrl,
    this.usedParts,
    this.paymentMethod,
    this.isPaid = false,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      organizationId: data['organizationId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      assignedWorkerId: data['assignedWorkerId'] as String,
      assignedWorkerName: data['assignedWorkerName'] as String,
      address: data['address'] as String,
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      status: _parseStatus(data['status'] as String),
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      missionNumber: data['missionNumber'] as String?,
      beforePhotoUrl: data['beforePhotoUrl'] as String?,
      afterPhotoUrl: data['afterPhotoUrl'] as String?,
      usedParts: (data['usedParts'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      paymentMethod: data['paymentMethod'] as String?,
      isPaid: data['isPaid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'title': title,
      'description': description,
      'assignedWorkerId': assignedWorkerId,
      'assignedWorkerName': assignedWorkerName,
      'address': address,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.name,
      'createdDate': Timestamp.fromDate(createdDate),
      'missionNumber': missionNumber,
      'beforePhotoUrl': beforePhotoUrl,
      'afterPhotoUrl': afterPhotoUrl,
      'usedParts': usedParts,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid,
    };
  }

  static JobStatus _parseStatus(String value) {
    return JobStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => JobStatus.notStarted,
    );
  }

  Job copyWith({
    String? title,
    String? description,
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? address,
    DateTime? scheduledDate,
    JobStatus? status,
    String? beforePhotoUrl,
    String? afterPhotoUrl,
    List<Map<String, dynamic>>? usedParts,
    String? paymentMethod,
    bool? isPaid,
  }) {
    return Job(
      id: id,
      organizationId: organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      address: address ?? this.address,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      createdDate: createdDate,
      missionNumber: missionNumber,
      beforePhotoUrl: beforePhotoUrl ?? this.beforePhotoUrl,
      afterPhotoUrl: afterPhotoUrl ?? this.afterPhotoUrl,
      usedParts: usedParts ?? this.usedParts,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
