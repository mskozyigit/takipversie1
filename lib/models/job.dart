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
  final String? description2;
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
  final List<String> beforePhotoUrls;
  final List<String> afterPhotoUrls;
  final List<Map<String, dynamic>>? usedParts;
  final String? paymentMethod; // 'qr' or 'cash'
  final bool isPaid;
  final Duration? estimatedTravelTime;
  final DateTime createdDate;
  final bool isSafetyConfirmed;
  final Map<String, bool>? safetyChecklist;
  final double? fee;
  final int durationHours;
  final List<String> checklistNotes;

  const Job({
    required this.id,
    required this.organizationId,
    required this.missionNumber,
    required this.title,
    required this.description,
    this.description2,
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
    this.beforePhotoUrls = const [],
    this.afterPhotoUrls = const [],
    this.usedParts,
    this.paymentMethod,
    this.isPaid = false,
    this.estimatedTravelTime,
    this.isSafetyConfirmed = false,
    this.safetyChecklist,
    this.fee,
    this.durationHours = 2,
    this.checklistNotes = const [],
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      organizationId: data['organizationId'] as String,
      missionNumber: data['missionNumber'] as String? ?? '',
      title: data['title'] as String,
      description: data['description'] as String,
      description2: data['description2'] as String?,
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
      beforePhotoUrls: _parsePhotoList(data, 'beforePhotoUrls', 'beforePhotoUrl'),
      afterPhotoUrls: _parsePhotoList(data, 'afterPhotoUrls', 'afterPhotoUrl'),
      usedParts: (data['usedParts'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      paymentMethod: data['paymentMethod'] as String?,
      isPaid: data['isPaid'] as bool? ?? false,
      estimatedTravelTime: (data['estimatedTravelTime'] ?? data['travelMinutes']) != null ? Duration(minutes: (data['estimatedTravelTime'] ?? data['travelMinutes']) as int) : null,
      isSafetyConfirmed: data['isSafetyConfirmed'] as bool? ?? false,
      safetyChecklist: data['safetyChecklist'] != null ? Map<String, bool>.from(data['safetyChecklist']) : null,
      fee: (data['fee'] as num?)?.toDouble(),
      durationHours: data['durationHours'] as int? ?? 2,
      checklistNotes: List<String>.from(data['checklistNotes'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'missionNumber': missionNumber,
      'title': title,
      'description': description,
      'description2': description2,
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
      'beforePhotoUrls': beforePhotoUrls,
      'afterPhotoUrls': afterPhotoUrls,
      'usedParts': usedParts,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid,
      'travelMinutes': estimatedTravelTime?.inMinutes,
      'isSafetyConfirmed': isSafetyConfirmed,
      'safetyChecklist': safetyChecklist,
      'fee': fee,
      'durationHours': durationHours,
      'checklistNotes': checklistNotes,
    };
  }

  static List<String> _parsePhotoList(Map<String, dynamic> data, String listKey, String singleKey) {
    // Önce yeni liste formatını dene
    if (data[listKey] != null) {
      return List<String>.from(data[listKey] as List);
    }
    // Eski tekli formatı listeye çevir (geriye dönük uyumluluk)
    final single = data[singleKey] as String?;
    if (single != null && single.isNotEmpty) {
      return [single];
    }
    return [];
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
    String? description2,
    String? assignedWorkerId,
    String? assignedWorkerName,
    String? address,
    String? customerName,
    String? customerPhone,
    DateTime? scheduledDate,
    JobStatus? status,
    List<String>? beforePhotoUrls,
    List<String>? afterPhotoUrls,
    List<Map<String, dynamic>>? usedParts,
    String? paymentMethod,
    bool? isPaid,
    List<String>? checklistNotes,
  }) {
    return Job(
      id: id,
      organizationId: organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      description2: description2 ?? this.description2,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      address: address ?? this.address,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      createdDate: createdDate,
      checklistNotes: checklistNotes ?? this.checklistNotes,
      missionNumber: missionNumber,
      beforePhotoUrls: beforePhotoUrls ?? this.beforePhotoUrls,
      afterPhotoUrls: afterPhotoUrls ?? this.afterPhotoUrls,
      usedParts: usedParts ?? this.usedParts,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
