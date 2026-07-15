import 'package:cloud_firestore/cloud_firestore.dart';

/// Minimal fake DocumentSnapshot for model unit tests.
/// Only implements the methods used by fromFirestore factories:
/// - id, exists, data(), operator []
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;
  final bool _exists;

  FakeDocumentSnapshot({
    required String id,
    required Map<String, dynamic> data,
    bool exists = true,
  })  : _id = id,
        _data = data,
        _exists = exists;

  @override
  String get id => _id;

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  Map<String, dynamic>? get dataOrNull => _data;

  @override
  Map<String, dynamic> get dataOrThrow {
    if (!_exists) throw StateError('Document does not exist');
    return _data;
  }

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  dynamic get(Object field, {Object Function(Object? value)? from}) {
    final value = _data[field];
    return from != null ? from(value) : value;
  }

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  FirebaseFirestore get firestore => throw UnimplementedError();

  @override
  DocumentReference<Map<String, dynamic>> get reference => throw UnimplementedError();
}
