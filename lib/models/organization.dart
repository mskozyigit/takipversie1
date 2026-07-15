import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String joinCode;
  final DateTime createdDate;
  final String activeLanguage;
  final String? paymentQrUrl;
  final Map<String, String> qrPaymentUrls; // {"150": "url", "200": "url", ...}
  final int lastMissionNumber;
  final Map<String, bool> enabledModules;

  final bool useBranding;
  final String? logoUrl;
  final String? primaryColorHex;

  const Organization({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.createdDate,
    this.activeLanguage = 'nl',
    this.paymentQrUrl,
    this.qrPaymentUrls = const {},
    this.lastMissionNumber = 1000,
    this.enabledModules = const {},
    this.useBranding = false,
    this.logoUrl,
    this.primaryColorHex,
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
      qrPaymentUrls: data['qrPaymentUrls'] != null
          ? Map<String, String>.from(data['qrPaymentUrls'])
          : const {},
      lastMissionNumber: data['lastMissionNumber'] as int? ?? 1000,
      enabledModules: Map<String, bool>.from(data['enabledModules'] ?? {}),
      useBranding: data['useBranding'] as bool? ?? false,
      logoUrl: data['logoUrl'] as String?,
      primaryColorHex: data['primaryColorHex'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'joinCode': joinCode,
      'createdDate': Timestamp.fromDate(createdDate),
      'activeLanguage': activeLanguage,
      'paymentQrUrl': paymentQrUrl,
      'qrPaymentUrls': qrPaymentUrls,
      'lastMissionNumber': lastMissionNumber,
      'enabledModules': enabledModules,
      'useBranding': useBranding,
      'logoUrl': logoUrl,
      'primaryColorHex': primaryColorHex,
    };
  }
}
