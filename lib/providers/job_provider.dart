import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import 'auth_provider.dart';

import '../models/audit_log.dart';
import '../models/comment.dart';

final _firestore = FirebaseFirestore.instance;

// -----------------------------------------------------------------------
// Audit Log Provider
// -----------------------------------------------------------------------

final auditLogProvider = StreamProvider.family<List<AuditLogEntry>, String>((ref, jobId) {
  final authState = ref.watch(authProvider).value;
  if (authState == null) return Stream.value([]);

  return _firestore
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

  return _firestore
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

  return _firestore
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

  return _firestore
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

  return _firestore
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

  return _firestore
      .collection('customers')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList());
});

/// Job Operations Notifier
class JobNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> createJob({
    required String title,
    required String description,
    required String assignedWorkerId,
    required String assignedWorkerName,
    required String address,
    String? customerName,
    String? customerPhone,
    required DateTime scheduledDate,
    List<String> descriptionBlocks = const [],
    double? distanceKm,
    double? fee,
  }) async {
    final authState = ref.read(authProvider).value;
    if (authState is! ApprovedAdmin) return;

    final orgId = authState.appUser.organizationId;
    final jobRef = _firestore.collection('jobs').doc();
    
    // LOG-01: Distance-based ETA calculation (Assume 50km/h + 15m buffer)
    Duration? estimatedTravel;
    if (distanceKm != null) {
      final minutes = (distanceKm / 50 * 60).round() + 15;
      estimatedTravel = Duration(minutes: minutes);
    }

    // JOB-06: Atomic sequential mission number
    final missionNumber = await _firestore.runTransaction((transaction) async {
      final orgDoc = await transaction.get(_firestore.collection('organizations').doc(orgId));
      final currentNum = (orgDoc.data()?['lastMissionNumber'] as int? ?? 1000) + 1;
      transaction.update(orgDoc.reference, {'lastMissionNumber': currentNum});
      return '#$currentNum';
    });

    final job = Job(
      id: jobRef.id,
      organizationId: orgId,
      missionNumber: missionNumber,
      title: title,
      description: description,
      descriptionBlocks: descriptionBlocks,
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
    );

    await jobRef.set(job.toFirestore());
    await _logAction(jobRef.id, 'Job Created', metadata: {'missionNumber': missionNumber});
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
    required DateTime scheduledDate,
    String? missionNumber,
  }) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    final data = {
      'title': title,
      'description': description,
      'assignedWorkerId': assignedWorkerId,
      'assignedWorkerName': assignedWorkerName,
      'address': address,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
    };

    if (missionNumber != null) {
      // Validate uniqueness if edited
      final collision = await _firestore
          .collection('jobs')
          .where('organizationId', isEqualTo: authState.appUser!.organizationId)
          .where('missionNumber', isEqualTo: missionNumber)
          .get();
      
      if (collision.docs.isNotEmpty && collision.docs.first.id != jobId) {
        final nextNum = (await _firestore.collection('organizations').doc(authState.appUser!.organizationId).get()).data()?['lastMissionNumber'] ?? 1000;
        final l10n = ref.read(translationProvider.notifier);
        throw Exception(l10n.translate('job_mission_collision', {'next': '#${nextNum + 1}'}));
      }
      data['missionNumber'] = missionNumber;
    }

    await _firestore.collection('jobs').doc(jobId).update(data);
    await _logAction(jobId, 'Job Updated');
  }

  Future<void> createCustomer({required String name, required String address, required String phone}) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await _firestore.collection('customers').add({
      'organizationId': authState.appUser!.organizationId,
      'name': name,
      'address': address,
      'phone': phone,
    });
  }

  Future<void> updateJobStatus(String jobId, JobStatus newStatus) async {
    final doc = await _firestore.collection('jobs').doc(jobId).get();
    final currentStatus = _parseStatus(doc.data()?['status']);

    // JOB-05: Duplicate-action guard (Idempotency)
    if (currentStatus == newStatus) return;

    await _firestore.collection('jobs').doc(jobId).update({
      'status': newStatus.name,
      if (newStatus == JobStatus.inProgress) 'startedAt': FieldValue.serverTimestamp(),
      if (newStatus == JobStatus.workCompleted) 'completedAt': FieldValue.serverTimestamp(),
    });

    await _logAction(jobId, 'Status changed to ${newStatus.name}');
  }

  Future<void> updateJobPhotos(String jobId, {String? beforeUrl, String? afterUrl}) async {
    final Map<String, dynamic> data = {};
    if (beforeUrl != null) data['beforePhotoUrl'] = beforeUrl;
    if (afterUrl != null) data['afterPhotoUrl'] = afterUrl;

    if (data.isNotEmpty) {
      await _firestore.collection('jobs').doc(jobId).update(data);
      await _logAction(jobId, 'Photos updated');
    }
  }

  Future<void> addJobPart(String jobId, Map<String, dynamic> part) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'usedParts': FieldValue.arrayUnion([part]),
    });
    await _logAction(jobId, 'Part added: ${part['name']}');
  }

  Future<void> addComment(String jobId, String text) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await _firestore.collection('comments').add({
      'jobId': jobId,
      'organizationId': authState.appUser!.organizationId,
      'authorId': authState.appUser!.id,
      'authorName': authState.appUser!.name,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSafetyChecklist(String jobId, Map<String, bool> checklist) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'safetyChecklist': checklist,
      'isSafetyConfirmed': !checklist.values.contains(false),
    });
    await _logAction(jobId, 'Safety Checklist Updated');
  }

  Future<void> recordPayment(String jobId, String method) async {
    final authState = ref.read(authProvider).value;
    final workerName = authState is ApprovedWorker ? authState.appUser.name : 'System';

    await _firestore.collection('jobs').doc(jobId).update({
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

  // ADM-03 Helper
  Future<void> _logAction(String jobId, String type, {Map<String, dynamic>? metadata}) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    await _firestore.collection('auditLogs').add({
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
