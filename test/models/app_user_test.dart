import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takipversie1/models/app_user.dart';
import '../test_helpers/fake_document_snapshot.dart';

void main() {
  group('AppUser.fromFirestore', () {
    final baseData = {
      'name': 'Test User',
      'email': 'test@example.com',
      'organizationId': 'org123',
      'role': 'admin',
      'approvalStatus': 'approved',
    };

    test('parses admin user correctly', () {
      final doc = FakeDocumentSnapshot(id: 'user1', data: baseData);
      final user = AppUser.fromFirestore(doc);

      expect(user.id, 'user1');
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.organizationId, 'org123');
      expect(user.role, UserRole.admin);
      expect(user.approvalStatus, ApprovalStatus.approved);
    });

    test('parses worker user correctly', () {
      final data = Map<String, dynamic>.from(baseData);
      data['role'] = 'worker';

      final doc = FakeDocumentSnapshot(id: 'user2', data: data);
      final user = AppUser.fromFirestore(doc);

      expect(user.role, UserRole.worker);
    });

    test('parses all approval status values', () {
      final statusMap = {
        'pending': ApprovalStatus.pending,
        'approved': ApprovalStatus.approved,
        'rejected': ApprovalStatus.rejected,
      };

      for (final entry in statusMap.entries) {
        final data = Map<String, dynamic>.from(baseData);
        data['approvalStatus'] = entry.key;
        final doc = FakeDocumentSnapshot(id: 'user1', data: data);
        final user = AppUser.fromFirestore(doc);
        expect(user.approvalStatus, entry.value,
            reason: 'Status "${entry.key}" should map to ${entry.value}');
      }
    });

    test('unknown approvalStatus defaults to pending', () {
      final data = Map<String, dynamic>.from(baseData);
      data['approvalStatus'] = 'unknown_value';

      final doc = FakeDocumentSnapshot(id: 'user1', data: data);
      final user = AppUser.fromFirestore(doc);

      expect(user.approvalStatus, ApprovalStatus.pending);
    });

    test('copyWith updates approval status only', () {
      final user = AppUser(
        id: 'user1',
        name: 'Test User',
        email: 'test@example.com',
        organizationId: 'org123',
        role: UserRole.admin,
        approvalStatus: ApprovalStatus.pending,
      );

      final updated = user.copyWith(approvalStatus: ApprovalStatus.approved);

      expect(updated.id, user.id);
      expect(updated.name, user.name);
      expect(updated.email, user.email);
      expect(updated.role, user.role);
      expect(updated.approvalStatus, ApprovalStatus.approved);
      // Original should be unchanged
      expect(user.approvalStatus, ApprovalStatus.pending);
    });

    test('toFirestore converts back to map', () {
      final user = AppUser(
        id: 'user1',
        name: 'Test User',
        email: 'test@example.com',
        organizationId: 'org123',
        role: UserRole.admin,
        approvalStatus: ApprovalStatus.approved,
      );

      final map = user.toFirestore();

      expect(map['name'], 'Test User');
      expect(map['email'], 'test@example.com');
      expect(map['organizationId'], 'org123');
      expect(map['role'], 'admin');
      expect(map['approvalStatus'], 'approved');
    });
  });
}
