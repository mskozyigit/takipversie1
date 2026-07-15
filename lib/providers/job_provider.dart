import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../models/job_template.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import 'auth_provider.dart';
import 'module_provider.dart';
import 'firestore_provider.dart';

import '../models/audit_log.dart';
import '../models/comment.dart';

// -----------------------------------------------------------------------
// Audit Log Provider
// -----------------------------------------------------------------------

final auditLogProvider = StreamProvider.family<List<AuditLogEntry>, String>((ref, jobId) {
  final authState = ref.watch(authProvider).value;
  if (authState == null) return Stream.value([]);

  return ref.read(firestoreProvider)
      .collection('auditLogs')
      .where('jobId', isEqualTo: jobId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => AuditLogEntry.fromFirestore(doc)).toList());
});

// -----------------------------------------------------------------------
// Comment Provider
// -----------------------------------------------------------------------

final commentsProvider = StreamProvider.family<List<JobComment>, String>((ref, jobId) {
  final authState = ref.watch(authProvider).value;
  final orgId = authState?.appUser?.organizationId;
  if (orgId == null) return Stream.value([]);

  return ref.read(firestoreProvider)
      .collection('comments')
      .where('jobId', isEqualTo: jobId)
      .where('organizationId', isEqualTo: orgId)
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => JobComment.fromFirestore(doc)).toList());
});

/// Organization-wide jobs stream (for Admins) - Month based
final allJobsProvider = StreamProvider.family<List<Job>, DateTime>((ref, date) {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedAdmin) return Stream.value([]);

  final start = DateTime(date.year, date.month, 1);
  final end = DateTime(date.year, date.month + 1, 1).subtract(const Duration(milliseconds: 1));

  return ref.read(firestoreProvider)
      .collection('jobs')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
      .snapshots()
      .map((snapshot) {
        final jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
        jobs.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
        return jobs;
      });
});

/// Worker-specific jobs stream - Month based
final workerJobsProvider = StreamProvider.family<List<Job>, DateTime>((ref, date) {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedWorker) return Stream.value([]);

  final start = DateTime(date.year, date.month, 1);
  final end = DateTime(date.year, date.month + 1, 1).subtract(const Duration(milliseconds: 1));

  return ref.read(firestoreProvider)
      .collection('jobs')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .where('assignedWorkerId', isEqualTo: authState.appUser.id)
      .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
      .snapshots()
      .map((snapshot) {
        final jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
        jobs.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
        return jobs;
      });
});

/// All approved workers in the organization (for Job Assignment)
final organizationWorkersProvider = StreamProvider<List<AppUser>>((ref) {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedAdmin) return Stream.value([]);

  return ref.read(firestoreProvider)
      .collection('users')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .where('approvalStatus', isEqualTo: 'approved')
      .where('role', isEqualTo: 'worker')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList());
});

/// CRM-01: Reusable customer directory
final customersProvider = StreamProvider<List<Customer>>((ref) {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedAdmin) return Stream.value([]);

  return ref.read(firestoreProvider)
      .collection('customers')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList());
});

// -----------------------------------------------------------------------
// Single Job by ID — canlı Firestore stream (ücret, durum, fotoğraf anlık)
// -----------------------------------------------------------------------

final jobByIdProvider = StreamProvider.family<Job?, String>((ref, jobId) {
  return ref.read(firestoreProvider).collection('jobs').doc(jobId).snapshots().map((doc) {
    if (!doc.exists) return null;
    return Job.fromFirestore(doc);
  });
});

/// Job Operations Notifier
class JobNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Returns the created job's document ID.
  /// If [id] is provided, uses it instead of auto-generating.
  Future<String> createJob({
    required String title,
    required String description,
    required String assignedWorkerId,
    required String assignedWorkerName,
    required String address,
    String? customerName,
    String? customerPhone,
    String? customerId,
    required DateTime scheduledDate,
    List<String> descriptionBlocks = const [],
    List<String> attachedImages = const [],
    double? distanceKm,
    double? fee,
    int durationHours = 2,
    String? missionNumber,
    String? id,
  }) async {
    final authState = ref.read(authProvider).value;
    if (authState is! ApprovedAdmin) return '';

    final l10n = ref.read(translationProvider.notifier);
    final orgId = authState.appUser.organizationId;
    final jobRef = ref.read(firestoreProvider).collection('jobs').doc(id);
    
    // LOG-01: Distance-based ETA calculation (Assume 50km/h + 15m buffer)
    Duration? estimatedTravel;
    if (distanceKm != null) {
      final minutes = (distanceKm / 50 * 60).round() + 15;
      estimatedTravel = Duration(minutes: minutes);
    }

    // JOB-06: Mission number — custom or auto-generated
    String finalMissionNumber;
    if (missionNumber != null && missionNumber.trim().isNotEmpty) {
      // Custom mission number: validate uniqueness
      final collision = await ref.read(firestoreProvider)
          .collection('jobs')
          .where('organizationId', isEqualTo: orgId)
          .where('missionNumber', isEqualTo: missionNumber.trim())
          .get();
      
      if (collision.docs.isNotEmpty) {
        final nextNum = (await ref.read(firestoreProvider).collection('organizations').doc(orgId).get()).data()?['lastMissionNumber'] ?? 1000;
        throw Exception(l10n.translate('job_mission_collision', {'next': '#${nextNum + 1}'}));
      }
      finalMissionNumber = missionNumber.trim();
    } else {
      // Auto-generate sequential mission number
      finalMissionNumber = await ref.read(firestoreProvider).runTransaction((transaction) async {
        final orgDoc = await transaction.get(ref.read(firestoreProvider).collection('organizations').doc(orgId));
        final currentNum = (orgDoc.data()?['lastMissionNumber'] as int? ?? 1000) + 1;
        transaction.update(orgDoc.reference, {'lastMissionNumber': currentNum});
        return '#$currentNum';
      });
    }

    final job = Job(
      id: jobRef.id,
      organizationId: orgId,
      missionNumber: finalMissionNumber,
      title: title,
      description: description,
      descriptionBlocks: descriptionBlocks,
      attachedImages: attachedImages,
      customerId: customerId,
      assignedWorkerId: assignedWorkerId,
      assignedWorkerName: assignedWorkerName,
      address: address,
      customerName: customerName,
      customerPhone: customerPhone,
      scheduledDate: scheduledDate,
      status: JobStatus.notStarted,
      createdDate: DateTime.now(),
      estimatedTravelTime: estimatedTravel,
      fee: fee,
      feeEnteredBy: fee != null ? 0 : null,
      durationHours: durationHours,
    );

    await jobRef.set(job.toFirestore());
    await _logAction(jobRef.id, 'Job Created', metadata: {'missionNumber': finalMissionNumber});

    // TEAM-02: Send push notification to assigned worker (skip if unassigned)
    if (assignedWorkerId != 'unassigned') {
      await _sendJobNotification(
        workerId: assignedWorkerId,
        title: l10n.translate('notification_new_job_title', {'title': title}),
        body: l10n.translate('notification_new_job_body', {'mission': finalMissionNumber, 'date': '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}'}),
        jobId: jobRef.id,
        orgId: orgId,
      );
    }
    return jobRef.id;
  }

  Future<void> updateJob({
    required String jobId,
    required String title,
    required String description,
    required String assignedWorkerId,
    required String assignedWorkerName,
    required String address,
    String? customerName,
    String? customerPhone,
    String? customerId,
    required DateTime scheduledDate,
    String? missionNumber,
    double? distanceKm,
    double? fee,
    int? durationHours,
    List<String>? descriptionBlocks,
    List<String>? attachedImages,
  }) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    // LOG-01: Distance-based ETA calculation
    Duration? estimatedTravel;
    if (distanceKm != null) {
      final minutes = (distanceKm / 50 * 60).round() + 15;
      estimatedTravel = Duration(minutes: minutes);
    }

    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'assignedWorkerId': assignedWorkerId,
      'assignedWorkerName': assignedWorkerName,
      'address': address,
      'customerName': customerName,
      'customerPhone': customerPhone,
      if (customerId != null) 'customerId': customerId,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
    };

    if (missionNumber != null && missionNumber.trim().isNotEmpty) {
      // Validate uniqueness if edited
      final collision = await ref.read(firestoreProvider)
          .collection('jobs')
          .where('organizationId', isEqualTo: authState.appUser!.organizationId)
          .where('missionNumber', isEqualTo: missionNumber.trim())
          .get();

      if (collision.docs.isNotEmpty && collision.docs.first.id != jobId) {
        final nextNum = (await ref.read(firestoreProvider).collection('organizations').doc(authState.appUser!.organizationId).get()).data()?['lastMissionNumber'] ?? 1000;
        final l10n = ref.read(translationProvider.notifier);
        throw Exception(l10n.translate('job_mission_collision', {'next': '#${nextNum + 1}'}));
      }
      data['missionNumber'] = missionNumber.trim();
    }

    if (distanceKm != null) data['distanceKm'] = distanceKm;
    if (fee != null) {
      data['fee'] = fee;
      data['feeEnteredBy'] = 0; // Admin tarafından girildi/düzenlendi
    }
    if (durationHours != null) data['durationHours'] = durationHours;
    if (descriptionBlocks != null) data['descriptionBlocks'] = descriptionBlocks;
    if (attachedImages != null) data['attachedImages'] = attachedImages;
    if (estimatedTravel != null) data['estimatedTravelTime'] = estimatedTravel.inMinutes;

    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update(data);
    await _logAction(jobId, 'Job Updated');

    // Notify newly assigned worker if different from before
    if (assignedWorkerId != 'unassigned') {
      final oldJob = await ref.read(firestoreProvider).collection('jobs').doc(jobId).get();
      final previousWorkerId = oldJob.data()?['assignedWorkerId'] as String?;
      if (previousWorkerId != assignedWorkerId) {
        final l10n = ref.read(translationProvider.notifier);
        final orgId = authState.appUser!.organizationId;
        await _sendJobNotification(
          workerId: assignedWorkerId,
          title: l10n.translate('notification_new_job_title', {'title': title}),
          body: l10n.translate('notification_new_job_body', {'mission': oldJob.data()?['missionNumber'] ?? '', 'date': '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}'}),
          jobId: jobId,
          orgId: orgId,
        );
      }
    }
  }

  /// Worker can add their own description (description2) to a job.
  /// Both worker and admin can call this.
  Future<void> updateDescription2(String jobId, String description2) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      'description2': description2,
    });
    await _logAction(jobId, 'Description2 Updated');
  }

  /// Worker can update the job fee in the field.
  Future<void> updateFee(String jobId, double fee) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      'fee': fee,
      'feeEnteredBy': 1, // Worker tarafından girildi
    });
    await _logAction(jobId, 'Fee Updated', metadata: {'fee': fee});
  }

  /// Worker can update the job duration (hours) in the field.
  Future<void> updateDuration(String jobId, int hours) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      'durationHours': hours,
    });
    await _logAction(jobId, 'Duration Updated', metadata: {'hours': hours});
  }

  /// Worker adds a note during the checklist flow (between photos).
  /// The note is appended to the checklistNotes list on the job document.
  Future<void> addChecklistNote(String jobId, String note) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      'checklistNotes': FieldValue.arrayUnion([note]),
    });
    await _logAction(jobId, 'Checklist Note Added');
  }

  Future<void> deleteJob(String jobId) async {
    final authState = ref.read(authProvider).value;
    if (authState is! ApprovedAdmin) return;

    await ref.read(firestoreProvider).collection('jobs').doc(jobId).delete();
    await _logAction(jobId, 'Job Deleted');
  }

  Future<void> createCustomer({required String name, required String address, required String phone}) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await ref.read(firestoreProvider).collection('customers').add({
      'organizationId': authState.appUser!.organizationId,
      'name': name,
      'address': address,
      'phone': phone,
    });
  }

  Future<void> updateJobStatus(String jobId, JobStatus newStatus) async {
    final doc = await ref.read(firestoreProvider).collection('jobs').doc(jobId).get();
    final currentStatus = _parseStatus(doc.data()?['status']);

    // JOB-05: Duplicate-action guard (Idempotency)
    if (currentStatus == newStatus) return;

    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      'status': newStatus.name,
      if (newStatus == JobStatus.inProgress) 'startedAt': FieldValue.serverTimestamp(),
      if (newStatus == JobStatus.workCompleted) 'completedAt': FieldValue.serverTimestamp(),
    });

    await _logAction(jobId, 'Status changed to ${newStatus.name}');
  }

  /// Set the full photo lists for before/after (used when deleting a photo).
  Future<void> updateJobPhotos(String jobId, {List<String>? beforeUrls, List<String>? afterUrls}) async {
    final Map<String, dynamic> data = {};
    if (beforeUrls != null) data['beforePhotoUrls'] = beforeUrls;
    if (afterUrls != null) data['afterPhotoUrls'] = afterUrls;

    if (data.isNotEmpty) {
      await ref.read(firestoreProvider).collection('jobs').doc(jobId).update(data);
      await _logAction(jobId, 'Photos updated');
    }
  }

  /// Add a single photo URL to the before or after list via arrayUnion.
  Future<void> addJobPhoto(String jobId, {required String url, required bool isBefore}) async {
    final field = isBefore ? 'beforePhotoUrls' : 'afterPhotoUrls';
    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      field: FieldValue.arrayUnion([url]),
    });
    await _logAction(jobId, 'Photo added (${isBefore ? "before" : "after"})');
  }

  Future<void> addJobPart(String jobId, Map<String, dynamic> part) async {
    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      'usedParts': FieldValue.arrayUnion([part]),
    });
    await _logAction(jobId, 'Part added: ${part['name']}');
  }

  Future<void> addComment(String jobId, String text) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await ref.read(firestoreProvider).collection('comments').add({
      'jobId': jobId,
      'organizationId': authState.appUser!.organizationId,
      'authorId': authState.appUser!.id,
      'authorName': authState.appUser!.name,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSafetyChecklist(String jobId, Map<String, bool> checklist) async {
    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      'safetyChecklist': checklist,
      'isSafetyConfirmed': !checklist.values.contains(false),
    });
    await _logAction(jobId, 'Safety Checklist Updated');
  }

  Future<void> recordPayment(String jobId, String method) async {
    final authState = ref.read(authProvider).value;
    final workerName = authState is ApprovedWorker ? authState.appUser.name : 'System';

    await ref.read(firestoreProvider).collection('jobs').doc(jobId).update({
      'paymentMethod': method,
      'isPaid': true,
      'status': JobStatus.closed.name,
      'closedAt': FieldValue.serverTimestamp(),
      'paymentConfirmedBy': workerName,
    });

    final action = method == 'cash' ? 'cash payment override' : 'payment received via $method';
    await _logAction(jobId, action, metadata: {
      'isPaid': true, 
      'method': method,
      'confirmedBy': workerName,
    });
  }

  // TEAM-02: Send push notification to worker via Firestore
  Future<void> _sendJobNotification({
    required String workerId,
    required String title,
    required String body,
    required String jobId,
    required String orgId,
  }) async {
    try {
      await ref.read(firestoreProvider).collection('notifications').add({
        'userId': workerId,
        'title': title,
        'body': body,
        'jobId': jobId,
        'organizationId': orgId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notification is non-critical; silently fail
    }
  }

  // ADM-03 Helper — only writes if ADM-03 audit log module is enabled
  Future<void> _logAction(String jobId, String type, {Map<String, dynamic>? metadata}) async {
    // Skip logging if audit module is disabled (saves Firestore space)
    final registry = ref.read(moduleRegistryProvider);
    if (!(registry['ADM-03'] ?? false)) return;

    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await ref.read(firestoreProvider).collection('auditLogs').add({
      'organizationId': authState.appUser!.organizationId,
      'actorId': authState.appUser!.id,
      'actorName': authState.appUser!.name,
      'actionType': type,
      'jobId': jobId,
      'timestamp': FieldValue.serverTimestamp(),
      if (metadata != null) 'metadata': metadata,
    });
  }

  static JobStatus _parseStatus(dynamic value) {
    return JobStatus.values.firstWhere((e) => e.name == value, orElse: () => JobStatus.notStarted);
  }
}

final jobOperationsProvider = NotifierProvider<JobNotifier, void>(() => JobNotifier());

// -----------------------------------------------------------------------
// JOB-07: Job Templates
// -----------------------------------------------------------------------

/// Stream of all templates for the current organization
final jobTemplatesProvider = StreamProvider<List<JobTemplate>>((ref) {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedAdmin) return Stream.value([]);

  return ref.read(firestoreProvider)
      .collection('jobTemplates')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .orderBy('createdDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => JobTemplate.fromFirestore(doc)).toList());
});

/// Template CRUD operations
class TemplateNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> createTemplate({
    required String name,
    bool includeTitle = true,
    bool includeDescription = true,
    bool includeDescriptionBlocks = false,
    bool includeCustomerName = false,
    bool includeCustomerPhone = false,
    bool includeAddress = false,
    bool includeFee = false,
    bool includeDistance = false,
    bool includeDuration = false,
    String defaultTitle = '',
    String defaultDescription = '',
    List<String> defaultDescriptionBlocks = const [],
    String defaultCustomerName = '',
    String defaultCustomerPhone = '',
    String defaultAddress = '',
    double? defaultFee,
    double? defaultDistance,
    int defaultDurationHours = 2,
  }) async {
    final authState = ref.read(authProvider).value;
    if (authState is! ApprovedAdmin) return;

    final template = JobTemplate(
      id: ref.read(firestoreProvider).collection('jobTemplates').doc().id,
      organizationId: authState.appUser.organizationId,
      name: name,
      createdDate: DateTime.now(),
      includeTitle: includeTitle,
      includeDescription: includeDescription,
      includeDescriptionBlocks: includeDescriptionBlocks,
      includeCustomerName: includeCustomerName,
      includeCustomerPhone: includeCustomerPhone,
      includeAddress: includeAddress,
      includeFee: includeFee,
      includeDistance: includeDistance,
      defaultTitle: defaultTitle,
      defaultDescription: defaultDescription,
      defaultDescriptionBlocks: defaultDescriptionBlocks,
      defaultCustomerName: defaultCustomerName,
      defaultCustomerPhone: defaultCustomerPhone,
      defaultAddress: defaultAddress,
      defaultFee: defaultFee,
      defaultDistance: defaultDistance,
      defaultDurationHours: defaultDurationHours,
    );

    await ref.read(firestoreProvider).collection('jobTemplates').doc(template.id).set(template.toFirestore());
  }

  Future<void> deleteTemplate(String templateId) async {
    await ref.read(firestoreProvider).collection('jobTemplates').doc(templateId).delete();
  }
}

final templateOperationsProvider = NotifierProvider<TemplateNotifier, void>(() => TemplateNotifier());
