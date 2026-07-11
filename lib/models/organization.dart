import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String joinCode;
  final DateTime createdDate;
  final String? paymentQrUrl;
  final int lastMissionNumber;
  final Map<String, bool> enabledModules;

  const Organization({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.createdDate,
    this.activeLanguage = 'nl',
    this.paymentQrUrl,
    this.lastMissionNumber = 1000,
    this.enabledModules = const {},
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] as String,
      joinCode: data['joinCode'] as String,
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      activeLanguage: data['activeLanguage'] as String? ?? 'nl',
      paymentQrUrl: data['paymentQrUrl'] as String?,
      lastMissionNumber: data['lastMissionNumber'] as int? ?? 1000,
      enabledModules: Map<String, bool>.from(data['enabledModules'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'joinCode': joinCode,
      'createdDate': Timestamp.fromDate(createdDate),
      'activeLanguage': activeLanguage,
      'paymentQrUrl': paymentQrUrl,
      'lastMissionNumber': lastMissionNumber,
      'enabledModules': enabledModules,
    };
  }
}
