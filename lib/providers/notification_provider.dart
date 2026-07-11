import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

// -----------------------------------------------------------------------
// Push Notification Provider (TEAM-02)
// -----------------------------------------------------------------------

class NotificationNotifier extends Notifier<bool> {
  bool _initialized = false;

  @override
  bool build() => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    
    final authState = ref.read(authProvider).value;
    if (authState == null) return;

    try {
      if (kIsWeb) {
        await _initializeWeb();
      }
      // Mobile FCM can be added here for Android/iOS
      _initialized = true;
      state = true;
    } catch (e) {
      // FCM initialization can fail silently - notifications are a bonus
      state = false;
    }
  }

  Future<void> _initializeWeb() async {
    // Dynamic import to avoid mobile compilation issues
    try {
      // Use dart:js interop for web FCM
      await _requestWebPermission();
    } catch (_) {
      // Web FCM not available (e.g., in non-HTTPS context)
    }
  }

  Future<void> _requestWebPermission() async {
    // Web notification permission is handled via JavaScript interop
    // For now, we store a flag that notifications are supported
    final authState = ref.read(authProvider).value;
    if (authState?.appUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(authState!.appUser!.id)
        .update({
      'pushEnabled': true,
    });
  }

  Future<void> disable() async {
    final authState = ref.read(authProvider).value;
    if (authState?.appUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(authState!.appUser!.id)
        .update({
      'pushEnabled': false,
    });

    _initialized = false;
    state = false;
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, bool>(
  () => NotificationNotifier(),
);

// -----------------------------------------------------------------------
// In-app notification state (snackbar-style)
// -----------------------------------------------------------------------

class InAppNotification {
  final String title;
  final String body;
  final DateTime timestamp;

  const InAppNotification({
    required this.title,
    required this.body,
    required this.timestamp,
  });
}

final inAppNotificationsProvider = StreamProvider<List<InAppNotification>>((ref) {
  final authState = ref.watch(authProvider).value;
  final uid = authState?.appUser?.id;
  if (uid == null) return Stream.value([]);

  // Listen for notifications stored in Firestore
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .where('read', isEqualTo: false)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => InAppNotification(
        title: doc.data()['title'] as String,
        body: doc.data()['body'] as String,
        timestamp: (doc.data()['timestamp'] as Timestamp).toDate(),
      )).toList());
});
