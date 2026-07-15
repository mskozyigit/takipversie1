import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takipversie1/models/job.dart';
import '../test_helpers/fake_document_snapshot.dart';

void main() {
  group('Job.fromFirestore', () {
    final baseData = {
      'organizationId': 'org123',
      'missionNumber': '#1001',
      'title': 'Test Job',
      'description': 'Test Description',
      'assignedWorkerId': 'worker1',
      'assignedWorkerName': 'Test Worker',
      'address': '123 Test St',
      'scheduledDate': Timestamp.fromDate(DateTime(2026, 7, 15, 10, 0)),
      'status': 'notStarted',
      'createdDate': Timestamp.fromDate(DateTime(2026, 7, 12)),
    };

    test('parses minimal job correctly', () {
      final doc = FakeDocumentSnapshot(
        id: 'job1',
        data: baseData,
      );

      final job = Job.fromFirestore(doc);

      expect(job.id, 'job1');
      expect(job.organizationId, 'org123');
      expect(job.missionNumber, '#1001');
      expect(job.title, 'Test Job');
      expect(job.description, 'Test Description');
      expect(job.assignedWorkerId, 'worker1');
      expect(job.assignedWorkerName, 'Test Worker');
      expect(job.address, '123 Test St');
      expect(job.scheduledDate, DateTime(2026, 7, 15, 10, 0));
      expect(job.status, JobStatus.notStarted);
      expect(job.createdDate, DateTime(2026, 7, 12));
    });

    test('parses all status values correctly', () {
      final statusMap = {
        'notStarted': JobStatus.notStarted,
        'inProgress': JobStatus.inProgress,
        'workCompleted': JobStatus.workCompleted,
        'closed': JobStatus.closed,
      };

      for (final entry in statusMap.entries) {
        final data = Map<String, dynamic>.from(baseData);
        data['status'] = entry.key;
        final doc = FakeDocumentSnapshot(id: 'job1', data: data);
        final job = Job.fromFirestore(doc);
        expect(job.status, entry.value, reason: 'Status "${entry.key}" should map to ${entry.value}');
      }
    });

    test('parses optional fields when absent', () {
      final doc = FakeDocumentSnapshot(id: 'job1', data: baseData);

      final job = Job.fromFirestore(doc);

      expect(job.customerId, isNull);
      expect(job.customerName, isNull);
      expect(job.customerPhone, isNull);
      expect(job.beforePhotoUrls, isEmpty);
      expect(job.afterPhotoUrls, isEmpty);
      expect(job.attachedImages, isEmpty);
      expect(job.descriptionBlocks, isEmpty);
      expect(job.checklistNotes, isEmpty);
      expect(job.paymentMethod, isNull);
      expect(job.isPaid, false);
      expect(job.isSafetyConfirmed, false);
      expect(job.fee, isNull);
      expect(job.durationHours, 2);
    });

    test('parses optional fields when present', () {
      final data = Map<String, dynamic>.from(baseData);
      data.addAll({
        'customerId': 'cust1',
        'customerName': 'Customer A',
        'customerPhone': '+905551234567',
        'beforePhotoUrls': ['https://storage/photo1.jpg'],
        'afterPhotoUrls': ['https://storage/photo2.jpg'],
        'attachedImages': ['https://storage/attached.jpg'],
        'descriptionBlocks': ['Block 1', 'Block 2'],
        'checklistNotes': ['Note 1'],
        'paymentMethod': 'qr',
        'isPaid': true,
        'isSafetyConfirmed': true,
        'fee': 150.0,
        'durationHours': 4,
      });

      final doc = FakeDocumentSnapshot(id: 'job1', data: data);
      final job = Job.fromFirestore(doc);

      expect(job.customerId, 'cust1');
      expect(job.customerName, 'Customer A');
      expect(job.customerPhone, '+905551234567');
      expect(job.beforePhotoUrls, ['https://storage/photo1.jpg']);
      expect(job.afterPhotoUrls, ['https://storage/photo2.jpg']);
      expect(job.attachedImages, ['https://storage/attached.jpg']);
      expect(job.descriptionBlocks, ['Block 1', 'Block 2']);
      expect(job.checklistNotes, ['Note 1']);
      expect(job.paymentMethod, 'qr');
      expect(job.isPaid, true);
      expect(job.isSafetyConfirmed, true);
      expect(job.fee, 150.0);
      expect(job.durationHours, 4);
    });

    test('backward compatibility: single beforePhotoUrl maps to list', () {
      final data = Map<String, dynamic>.from(baseData);
      data['beforePhotoUrl'] = 'https://storage/single.jpg';

      final doc = FakeDocumentSnapshot(id: 'job1', data: data);
      final job = Job.fromFirestore(doc);

      expect(job.beforePhotoUrls, ['https://storage/single.jpg']);
    });

    test('backward compatibility: travelMinutes parses into Duration', () {
      final data = Map<String, dynamic>.from(baseData);
      data['travelMinutes'] = 45;

      final doc = FakeDocumentSnapshot(id: 'job1', data: data);
      final job = Job.fromFirestore(doc);

      expect(job.estimatedTravelTime, Duration(minutes: 45));
    });

    test('parses fee as double from int', () {
      final data = Map<String, dynamic>.from(baseData);
      data['fee'] = 100;

      final doc = FakeDocumentSnapshot(id: 'job1', data: data);
      final job = Job.fromFirestore(doc);

      expect(job.fee, 100.0);
      expect(job.fee, isA<double>());
    });

    test('empty missionNumber defaults to empty string', () {
      final data = Map<String, dynamic>.from(baseData);
      // missionNumber not in data → should default to ''
      data.remove('missionNumber');

      final doc = FakeDocumentSnapshot(id: 'job1', data: data);
      final job = Job.fromFirestore(doc);

      expect(job.missionNumber, '');
    });
  });

  group('Job.toFirestore', () {
    test('converts job back to map for Firestore write', () {
      final job = Job(
        id: 'job1',
        organizationId: 'org123',
        missionNumber: '#1001',
        title: 'Test Job',
        description: 'Test Desc',
        assignedWorkerId: 'worker1',
        assignedWorkerName: 'Worker',
        address: 'Address',
        scheduledDate: DateTime(2026, 7, 15, 10, 0),
        status: JobStatus.notStarted,
        createdDate: DateTime(2026, 7, 12),
        fee: 150.0,
        customerName: 'Customer',
        customerPhone: '+905551234567',
      );

      final map = job.toFirestore();

      expect(map['organizationId'], 'org123');
      expect(map['missionNumber'], '#1001');
      expect(map['title'], 'Test Job');
      expect(map['description'], 'Test Desc');
      expect(map['status'], 'notStarted');
      expect(map['fee'], 150.0);
      expect(map['customerName'], 'Customer');
      // Timestamps should be set for date fields
      expect(map['scheduledDate'], isA<Timestamp>());
      expect(map['createdDate'], isA<Timestamp>());
    });

    test('round-trip: toFirestore → fromFirestore preserves core fields', () {
      final original = Job(
        id: 'job1',
        organizationId: 'org123',
        missionNumber: '#1001',
        title: 'Round Trip',
        description: 'Testing round trip',
        assignedWorkerId: 'worker1',
        assignedWorkerName: 'Worker',
        address: 'Address',
        scheduledDate: DateTime(2026, 7, 15, 10, 0),
        status: JobStatus.inProgress,
        createdDate: DateTime(2026, 7, 12),
        attachedImages: ['url1', 'url2'],
        descriptionBlocks: ['Block 1'],
        beforePhotoUrls: ['photo1'],
        fee: 250.0,
        durationHours: 3,
        isPaid: true,
      );

      final map = original.toFirestore();
      map['id'] = original.id; // id is not in toFirestore output
      final doc = FakeDocumentSnapshot(id: original.id, data: map);
      final restored = Job.fromFirestore(doc);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.status, original.status);
      expect(restored.attachedImages, original.attachedImages);
      expect(restored.descriptionBlocks, original.descriptionBlocks);
      expect(restored.beforePhotoUrls, original.beforePhotoUrls);
      expect(restored.fee, original.fee);
      expect(restored.durationHours, original.durationHours);
      expect(restored.isPaid, original.isPaid);
    });
  });
}
