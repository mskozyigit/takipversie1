import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takipversie1/models/job.dart';

/// Business logic tests using FakeFirebaseFirestore.
/// Validates document structure, transactions, queries, and data integrity.

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('Firestore document structure', () {
    test('job document round-trips correctly', () async {
      await firestore.collection('organizations').doc('org-test').set({
        'lastMissionNumber': 1000,
        'activeLanguage': 'tr',
      });

      final job = Job(
        id: 'job-test-1',
        organizationId: 'org-test',
        missionNumber: '#1001',
        title: 'Integration Test Job',
        description: 'Testing Firestore round-trip',
        assignedWorkerId: 'worker1',
        assignedWorkerName: 'Test Worker',
        address: '123 Test St',
        scheduledDate: DateTime(2026, 7, 15, 10, 0),
        status: JobStatus.notStarted,
        createdDate: DateTime(2026, 7, 12),
        fee: 150.0,
        durationHours: 3,
        attachedImages: ['https://storage/photo1.jpg'],
        descriptionBlocks: ['Block 1'],
        customerName: 'Customer A',
        customerPhone: '+905551234567',
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
        'organizationId': 'org-test',
        'missionNumber': '#1001',
        'title': 'Status Test',
        'description': 'Testing',
        'assignedWorkerId': 'worker1',
        'assignedWorkerName': 'Worker',
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
          if (next == 'workCompleted')
            'completedAt': FieldValue.serverTimestamp(),
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
          id: 'query-job-$i',
          organizationId: 'org-test',
          missionNumber: '#${1000 + i}',
          title: 'Job $i',
          description: 'Description $i',
          assignedWorkerId: 'worker1',
          assignedWorkerName: 'Worker',
          address: 'Addr $i',
          scheduledDate: DateTime(2026, 7, i + 10),
          status: JobStatus.notStarted,
          createdDate: DateTime(2026, 7, 1),
        );
        await firestore.collection('jobs').doc(job.id).set(job.toFirestore());
      }

      await firestore.collection('jobs').doc('other-org-job').set({
        'organizationId': 'other-org',
        'missionNumber': '#9999',
        'title': 'Other Org',
        'description': 'No',
        'assignedWorkerId': 'worker1',
        'assignedWorkerName': 'Worker',
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
        'organizationId': 'org-test',
        'name': 'Test Customer',
        'address': 'Customer Address',
        'phone': '+905551234567',
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
        'organizationId': 'org-test',
        'missionNumber': '#1001',
        'title': 'Minimal',
        'description': 'Minimal',
        'assignedWorkerId': 'worker1',
        'assignedWorkerName': 'Worker',
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
}
