import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents which fields are included and their default values in a job template.
class JobTemplate {
  final String id;
  final String organizationId;
  final String name;
  final DateTime createdDate;

  // Which fields to include
  final bool includeTitle;
  final bool includeDescription;
  final bool includeDescriptionBlocks;
  final bool includeCustomerName;
  final bool includeCustomerPhone;
  final bool includeAddress;
  final bool includeFee;
  final bool includeDistance;
  final bool includeDuration;

  // Default values (only used if the corresponding include flag is true)
  final String defaultTitle;
  final String defaultDescription;
  final List<String> defaultDescriptionBlocks;
  final String defaultCustomerName;
  final String defaultCustomerPhone;
  final String defaultAddress;
  final double? defaultFee;
  final double? defaultDistance;
  final int defaultDurationHours;

  const JobTemplate({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.createdDate,
    this.includeTitle = true,
    this.includeDescription = true,
    this.includeDescriptionBlocks = false,
    this.includeCustomerName = false,
    this.includeCustomerPhone = false,
    this.includeAddress = false,
    this.includeFee = false,
    this.includeDistance = false,
    this.includeDuration = false,
    this.defaultTitle = '',
    this.defaultDescription = '',
    this.defaultDescriptionBlocks = const [],
    this.defaultCustomerName = '',
    this.defaultCustomerPhone = '',
    this.defaultAddress = '',
    this.defaultFee,
    this.defaultDistance,
    this.defaultDurationHours = 2,
  });

  factory JobTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobTemplate(
      id: doc.id,
      organizationId: data['organizationId'] as String,
      name: data['name'] as String,
      createdDate: (data['createdDate'] as Timestamp).toDate(),
      includeTitle: data['includeTitle'] as bool? ?? true,
      includeDescription: data['includeDescription'] as bool? ?? true,
      includeDescriptionBlocks: data['includeDescriptionBlocks'] as bool? ?? false,
      includeCustomerName: data['includeCustomerName'] as bool? ?? false,
      includeCustomerPhone: data['includeCustomerPhone'] as bool? ?? false,
      includeAddress: data['includeAddress'] as bool? ?? false,
      includeFee: data['includeFee'] as bool? ?? false,
      includeDistance: data['includeDistance'] as bool? ?? false,
      includeDuration: data['includeDuration'] as bool? ?? false,
      defaultTitle: data['defaultTitle'] as String? ?? '',
      defaultDescription: data['defaultDescription'] as String? ?? '',
      defaultDescriptionBlocks: List<String>.from(data['defaultDescriptionBlocks'] ?? []),
      defaultCustomerName: data['defaultCustomerName'] as String? ?? '',
      defaultCustomerPhone: data['defaultCustomerPhone'] as String? ?? '',
      defaultAddress: data['defaultAddress'] as String? ?? '',
      defaultFee: (data['defaultFee'] as num?)?.toDouble(),
      defaultDistance: (data['defaultDistance'] as num?)?.toDouble(),
      defaultDurationHours: data['defaultDurationHours'] as int? ?? 2,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'name': name,
      'createdDate': Timestamp.fromDate(createdDate),
      'includeTitle': includeTitle,
      'includeDescription': includeDescription,
      'includeDescriptionBlocks': includeDescriptionBlocks,
      'includeCustomerName': includeCustomerName,
      'includeCustomerPhone': includeCustomerPhone,
      'includeAddress': includeAddress,
      'includeFee': includeFee,
      'includeDistance': includeDistance,
      'includeDuration': includeDuration,
      'defaultTitle': defaultTitle,
      'defaultDescription': defaultDescription,
      'defaultDescriptionBlocks': defaultDescriptionBlocks,
      'defaultCustomerName': defaultCustomerName,
      'defaultCustomerPhone': defaultCustomerPhone,
      'defaultAddress': defaultAddress,
      'defaultFee': defaultFee,
      'defaultDistance': defaultDistance,
      'defaultDurationHours': defaultDurationHours,
    };
  }
}
