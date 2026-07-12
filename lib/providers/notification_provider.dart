import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
      final messaging = FirebaseMessaging.instance;

      // Request permission (web: triggers browser prompt)
      if (kIsWeb) {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          state = false;
          return;
        }
      } else {
        // Mobile: request permission via native APIs
        await messaging.requestPermission();
      }

      // Get FCM token and store it
      final token = await messaging.getToken();
      if (token != null && authState.appUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authState.appUser!.id)
            .update({'fcmToken': token, 'pushEnabled': true});
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        if (authState.appUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(authState.appUser!.id)
              .update({'fcmToken': newToken});
        }
      });

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Messages are also stored in Firestore (handled by inAppNotificationsProvider)
        // This callback can trigger local UI updates if needed
      });

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // Navigate to job detail if jobId is present
      });

      // Handle notification that launched the app from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        // Handle initial message navigation
      }

      _initialized = true;
      state = true;
    } catch (e) {
      // FCM initialization can fail silently - notifications are a bonus
      state = false;
    }
  }

  Future<void> disable() async {
    final authState = ref.read(authProvider).value;
    if (authState?.appUser == null) return;

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}

    await FirebaseFirestore.instance
        .collection('users')
        .doc(authState!.appUser!.id)
        .update({
      'pushEnabled': false,
      'fcmToken': FieldValue.delete(),
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
  final String id;
  final String title;
  final String body;
  final String? jobId;
  final DateTime timestamp;

  const InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.jobId,
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
        id: doc.id,
        title: doc.data()['title'] as String,
        body: doc.data()['body'] as String,
        jobId: doc.data()['jobId'] as String?,
        timestamp: (doc.data()['timestamp'] as Timestamp).toDate(),
      )).toList());
});
