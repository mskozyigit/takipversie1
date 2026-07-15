import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takipversie1/models/app_user.dart';
import 'package:takipversie1/models/job.dart';
import 'package:takipversie1/providers/auth_provider.dart';
import 'package:takipversie1/providers/firestore_provider.dart';
import 'package:takipversie1/providers/job_provider.dart';

/// Test suite for Job model, Firestore operations, and JobNotifier provider.
/// Run all: flutter test --no-pub

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  // ═══════════════════════════════════════════════════════
  // Document structure & round-trip tests
  // ═══════════════════════════════════════════════════════
  group('Firestore document structure', () {
    test('job document round-trips correctly', () async {
      await firestore.collection('organizations').doc('org-test').set({
        'lastMissionNumber': 1000, 'activeLanguage': 'tr',
      });

      final job = Job(
        id: 'job-test-1', organizationId: 'org-test',
        missionNumber: '#1001', title: 'Integration Test Job',
        description: 'Testing Firestore round-trip',
        assignedWorkerId: 'worker1', assignedWorkerName: 'Test Worker',
        address: '123 Test St',
        scheduledDate: DateTime(2026, 7, 15, 10, 0),
        status: JobStatus.notStarted, createdDate: DateTime(2026, 7, 12),
        fee: 150.0, durationHours: 3,
        attachedImages: ['https://storage/photo1.jpg'],
        descriptionBlocks: ['Block 1'],
        customerName: 'Customer A', customerPhone: '+905551234567',
      );

      await firestore.collection('jobs').doc(job.id).set(job.toFirestore());
      final doc = await firestore.collection('jobs').doc(job.id).get();
      expect(doc.exists, isTrue);

      final restored = Job.fromFirestore(doc);
      expect(restored.id, job.id);
      expect(restored.title, job.title);
      expect(restored.fee, job.fee);
      expect(restored.attachedImages, job.attachedImages);
      expect(restored.customerName, job.customerName);
      expect(restored.status, job.status);
    });

    test('transaction increments lastMissionNumber', () async {
      await firestore.collection('organizations').doc('org-test').set({
        'lastMissionNumber': 1000,
      });

      final result = await firestore.runTransaction<int>((transaction) async {
        final orgDoc = await transaction.get(
          firestore.collection('organizations').doc('org-test'),
        );
        final currentNum = (orgDoc.data()?['lastMissionNumber'] as int?) ?? 1000;
        final nextNum = currentNum + 1;
        transaction.update(orgDoc.reference, {'lastMissionNumber': nextNum});
        return nextNum;
      });

      expect(result, 1001);
      final updated = await firestore.collection('organizations').doc('org-test').get();
      expect(updated.data()!['lastMissionNumber'], 1001);
    });

    test('job status transitions correctly', () async {
      await firestore.collection('jobs').doc('job-status-test').set({
        'organizationId': 'org-test', 'missionNumber': '#1001',
        'title': 'Status Test', 'description': 'Testing',
        'assignedWorkerId': 'worker1', 'assignedWorkerName': 'Worker',
        'address': 'Addr',
        'scheduledDate': Timestamp.fromDate(DateTime(2026, 7, 15)),
        'status': 'notStarted',
        'createdDate': Timestamp.fromDate(DateTime(2026, 7, 12)),
      });

      final transitions = ['inProgress', 'workCompleted', 'closed'];
      for (final next in transitions) {
        await firestore.collection('jobs').doc('job-status-test').update({
          'status': next,
          if (next == 'inProgress') 'startedAt': FieldValue.serverTimestamp(),
          if (next == 'workCompleted') 'completedAt': FieldValue.serverTimestamp(),
        });
      }

      final doc = await firestore.collection('jobs').doc('job-status-test').get();
      final job = Job.fromFirestore(doc);
      expect(job.status, JobStatus.closed);
    });

    test('query filters by organizationId', () async {
      await firestore.collection('organizations').doc('org-test').set({
        'lastMissionNumber': 1000,
      });

      for (var i = 1; i <= 3; i++) {
        final job = Job(
          id: 'query-job-$i', organizationId: 'org-test',
          missionNumber: '#${1000 + i}', title: 'Job $i',
          description: 'Description $i',
          assignedWorkerId: 'worker1', assignedWorkerName: 'Worker',
          address: 'Addr $i',
          scheduledDate: DateTime(2026, 7, i + 10),
          status: JobStatus.notStarted, createdDate: DateTime(2026, 7, 1),
        );
        await firestore.collection('jobs').doc(job.id).set(job.toFirestore());
      }

      await firestore.collection('jobs').doc('other-org-job').set({
        'organizationId': 'other-org', 'missionNumber': '#9999',
        'title': 'Other Org', 'description': 'No',
        'assignedWorkerId': 'worker1', 'assignedWorkerName': 'Worker',
        'address': 'Addr',
        'scheduledDate': Timestamp.fromDate(DateTime(2026, 7, 15)),
        'status': 'notStarted',
        'createdDate': Timestamp.fromDate(DateTime(2026, 7, 1)),
      });

      final snapshot = await firestore
          .collection('jobs')
          .where('organizationId', isEqualTo: 'org-test')
          .get();
      expect(snapshot.docs.length, 3);
    });

    test('customer CRUD: create and query', () async {
      await firestore.collection('customers').add({
        'organizationId': 'org-test', 'name': 'Test Customer',
        'address': 'Customer Address', 'phone': '+905551234567',
      });

      final snapshot = await firestore
          .collection('customers')
          .where('organizationId', isEqualTo: 'org-test')
          .get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['name'], 'Test Customer');
    });

    test('null safety: missing optional fields get safe defaults', () async {
      await firestore.collection('jobs').doc('minimal-job').set({
        'organizationId': 'org-test', 'missionNumber': '#1001',
        'title': 'Minimal', 'description': 'Minimal',
        'assignedWorkerId': 'worker1', 'assignedWorkerName': 'Worker',
        'address': 'Addr',
        'scheduledDate': Timestamp.fromDate(DateTime(2026, 7, 15)),
        'status': 'notStarted',
        'createdDate': Timestamp.fromDate(DateTime(2026, 7, 12)),
      });

      final doc = await firestore.collection('jobs').doc('minimal-job').get();
      final job = Job.fromFirestore(doc);

      expect(job.customerName, isNull);
      expect(job.attachedImages, isEmpty);
      expect(job.beforePhotoUrls, isEmpty);
      expect(job.fee, isNull);
      expect(job.isPaid, false);
      expect(job.durationHours, 2);
    });
  });

  // ═══════════════════════════════════════════════════════
  // JobNotifier provider-level unit tests
  // ═══════════════════════════════════════════════════════
  group('JobNotifier (provider)', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    final testAdmin = AppUser(
      id: 'admin1', organizationId: 'org-test',
      name: 'Test Admin', email: 'admin@test.com',
      role: UserRole.admin, approvalStatus: ApprovalStatus.approved,
    );

    final testWorker = AppUser(
      id: 'worker1', organizationId: 'org-test',
      name: 'Test Worker', email: 'worker@test.com',
      role: UserRole.worker, approvalStatus: ApprovalStatus.approved,
    );

    ProviderContainer _workerContainer() => ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        authProvider.overrideWith(() { final n = AuthNotifier(); n.state = AsyncValue.data(ApprovedWorker(testWorker)); return n; }),
      ],
    );

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await firestore.collection('organizations').doc('org-test').set({
        'lastMissionNumber': 1000, 'activeLanguage': 'tr',
      });
      await firestore.collection('users').doc('admin1').set({
        'organizationId': 'org-test', 'name': 'Test Admin',
        'email': 'admin@test.com', 'role': 'admin',
        'approvalStatus': 'approved',
      });

      container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          authProvider.overrideWith(() { final n = AuthNotifier(); n.state = AsyncValue.data(ApprovedAdmin(testAdmin)); return n; }),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // Provider tests validate auth gating & error handling.
    // Full CRUD tests need real Firestore emulator (see firebase.json).

    test('createJob blocks non-admin (returns empty)', () async {
      final wc = _workerContainer();
      final notifier = wc.read(jobOperationsProvider.notifier);
      final result = await notifier.createJob(
        title: 'Fail', description: 'Fail',
        assignedWorkerId: 'worker1', assignedWorkerName: 'Worker',
        address: 'Addr', scheduledDate: DateTime(2026, 7, 15),
      );
      expect(result, '');
      wc.dispose();
    });

    test('deleteJob blocked for non-admin', () async {
      // First create as admin
      final notifier = container.read(jobOperationsProvider.notifier);
      await firestore.collection('jobs').doc('admin-job-1').set({
        'organizationId': 'org-test', 'missionNumber': '#ADM-001',
        'title': 'Admin Job', 'description': 'Admin only',
        'assignedWorkerId': 'worker1', 'assignedWorkerName': 'Worker',
        'address': 'Addr',
        'scheduledDate': Timestamp.fromDate(DateTime(2026, 7, 15)),
        'status': 'notStarted',
        'createdDate': Timestamp.fromDate(DateTime(2026, 7, 12)),
      });

      final wc = _workerContainer();
      await wc.read(jobOperationsProvider.notifier).deleteJob('admin-job-1');
      final doc = await firestore.collection('jobs').doc('admin-job-1').get();
      expect(doc.exists, isTrue); // Worker can't delete
      wc.dispose();
    });
  });
}
