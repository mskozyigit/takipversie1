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
  final String missionNumber;
  final String title;
  final String description;
  final List<String> descriptionBlocks;
  final List<String> attachedImages;
  final String? customerId;
  final String assignedWorkerId;
  final String assignedWorkerName;
  final String address;
  final String? customerName;
  final String? customerPhone;
  final DateTime scheduledDate;
  final JobStatus status;
  final String? beforePhotoUrl;
  final String? afterPhotoUrl;
  final List<Map<String, dynamic>>? usedParts;
  final String? paymentMethod; // 'qr' or 'cash'
  final bool isPaid;
  final Duration? estimatedTravelTime;
  final DateTime createdDate;
  final bool isSafetyConfirmed;
  final Map<String, bool>? safetyChecklist;
  final double? fee;

  const Job({
    required this.id,
    required this.organizationId,
    required this.missionNumber,
    required this.title,
    required this.description,
    this.descriptionBlocks = const [],
    this.attachedImages = const [],
    this.customerId,
    required this.assignedWorkerId,
    required this.assignedWorkerName,
    required this.address,
    this.customerName,
    this.customerPhone,
    required this.scheduledDate,
    required this.status,
    required this.createdDate,
    this.beforePhotoUrl,
    this.afterPhotoUrl,
    this.usedParts,
    this.paymentMethod,
    this.isPaid = false,
    this.estimatedTravelTime,
    this.isSafetyConfirmed = false,
    this.safetyChecklist,
    this.fee,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      organizationId: data['organizationId'] as String,
      missionNumber: data['missionNumber'] as String? ?? '',
      title: data['title'] as String,
      description: data['description'] as String,
      descriptionBlocks: List<String>.from(data['descriptionBlocks'] ?? []),
      attachedImages: List<String>.from(data['attachedImages'] ?? []),
      customerId: data['customerId'] as String?,
      assignedWorkerId: data['assignedWorkerId'] as String,
      assignedWorkerName: data['assignedWorkerName'] as String,
      address: data['address'] as String,
      customerName: data['customerName'] as String?,
      customerPhone: data['customerPhone'] as String?,
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      status: _parseStatus(data['status'] as String),
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      beforePhotoUrl: data['beforePhotoUrl'] as String?,
      afterPhotoUrl: data['afterPhotoUrl'] as String?,
      usedParts: (data['usedParts'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      paymentMethod: data['paymentMethod'] as String?,
      isPaid: data['isPaid'] as bool? ?? false,
      estimatedTravelTime: data['travelMinutes'] != null ? Duration(minutes: data['travelMinutes'] as int) : null,
      isSafetyConfirmed: data['isSafetyConfirmed'] as bool? ?? false,
      safetyChecklist: data['safetyChecklist'] != null ? Map<String, bool>.from(data['safetyChecklist']) : null,
      fee: (data['fee'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'missionNumber': missionNumber,
      'title': title,
      'description': description,
      'descriptionBlocks': descriptionBlocks,
      'attachedImages': attachedImages,
      'customerId': customerId,
      'assignedWorkerId': assignedWorkerId,
      'assignedWorkerName': assignedWorkerName,
      'address': address,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.name,
      'createdDate': Timestamp.fromDate(createdDate),
      'beforePhotoUrl': beforePhotoUrl,
      'afterPhotoUrl': afterPhotoUrl,
      'usedParts': usedParts,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid,
      'travelMinutes': estimatedTravelTime?.inMinutes,
      'isSafetyConfirmed': isSafetyConfirmed,
      'safetyChecklist': safetyChecklist,
      'fee': fee,
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
    String? customerName,
    String? customerPhone,
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
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
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
