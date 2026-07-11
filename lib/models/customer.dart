import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String organizationId;
  final String name;
  final String address;
  final String phone;

  const Customer({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.address,
    required this.phone,
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      organizationId: data['organizationId'] as String,
      name: data['name'] as String,
      address: data['address'] as String,
      phone: data['phone'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'name': name,
      'address': address,
      'phone': phone,
    };
  }
}
