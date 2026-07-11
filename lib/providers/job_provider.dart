import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../models/app_user.dart';
import 'auth_provider.dart';

final _firestore = FirebaseFirestore.instance;

/// Organization-wide jobs stream (for Admins)
final allJobsProvider = StreamProvider<List<Job>>((ref) {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedAdmin) return Stream.value([]);

  return _firestore
      .collection('jobs')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .orderBy('scheduledDate', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList());
});

/// Worker-specific jobs stream
final workerJobsProvider = StreamProvider<List<Job>>((ref) {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedWorker) return Stream.value([]);

  return _firestore
      .collection('jobs')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .where('assignedWorkerId', isEqualTo: authState.appUser.id)
      .orderBy('scheduledDate', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList());
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
    required DateTime scheduledDate,
  }) async {
    final authState = ref.read(authProvider).value;
    if (authState is! ApprovedAdmin) return;

    final jobRef = _firestore.collection('jobs').doc();
    final job = Job(
      id: jobRef.id,
      organizationId: authState.appUser.organizationId,
      title: title,
      description: description,
      assignedWorkerId: assignedWorkerId,
      assignedWorkerName: assignedWorkerName,
      address: address,
      scheduledDate: scheduledDate,
      status: JobStatus.notStarted,
      createdDate: DateTime.now(),
    );

    await jobRef.set(job.toFirestore());
  }

  Future<void> updateJobStatus(String jobId, JobStatus newStatus) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'status': newStatus.name,
    });
  }

  Future<void> updateJobPhotos(String jobId, {String? beforeUrl, String? afterUrl}) async {
    final Map<String, dynamic> data = {};
    if (beforeUrl != null) data['beforePhotoUrl'] = beforeUrl;
    if (afterUrl != null) data['afterPhotoUrl'] = afterUrl;

    if (data.isNotEmpty) {
      await _firestore.collection('jobs').doc(jobId).update(data);
    }
  }

  Future<void> addJobPart(String jobId, Map<String, dynamic> part) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'usedParts': FieldValue.arrayUnion([part]),
    });
  }

  Future<void> recordPayment(String jobId, String method) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'paymentMethod': method,
      'isPaid': true,
    });
  }
}

final jobOperationsProvider = NotifierProvider<JobNotifier, void>(() => JobNotifier());
