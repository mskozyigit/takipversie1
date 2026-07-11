import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String joinCode;
  final DateTime createdDate;
  final String activeLanguage;

  const Organization({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.createdDate,
    this.activeLanguage = 'nl',
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] as String,
      joinCode: data['joinCode'] as String,
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      activeLanguage: data['activeLanguage'] as String? ?? 'nl',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'joinCode': joinCode,
      'createdDate': Timestamp.fromDate(createdDate),
      'activeLanguage': activeLanguage,
    };
  }
}
