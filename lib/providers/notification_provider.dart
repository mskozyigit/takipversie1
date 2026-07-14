import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final _auth = FirebaseAuth.instance;

// -----------------------------------------------------------------------
// Push Notification Provider (TEAM-02)
// -----------------------------------------------------------------------

/// Bildirime tıklandığında yönlendirilecek işin ID'sini tutar.
/// UI tarafından watch edilir, değiştiğinde JobDetailScreen'e gidilir.
class PendingJobIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? jobId) => state = jobId;
  void clear() => state = null;
}

final pendingJobIdProvider = NotifierProvider<PendingJobIdNotifier, String?>(
  () => PendingJobIdNotifier(),
);

class NotificationNotifier extends Notifier<bool> {
  bool _initialized = false;
  StreamSubscription? _tokenSub;
  StreamSubscription? _messageSub;
  StreamSubscription? _messageOpenSub;

  @override
  bool build() {
    // Provider dispose olduğunda listener'ları temizle
    ref.onDispose(_cleanup);
    return _initialized;
  }

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
      _tokenSub = messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (doc.exists) {
            await doc.reference.update({'fcmToken': newToken});
          }
        }
      });

      // Foreground message handler — uygulama açıkken bildirim gelirse
      _messageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final jobId = message.data['jobId'];
        // pendingJobId'yi set et ki kullanıcı isterse tıklayıp gidebilsin
        if (jobId != null && jobId.isNotEmpty) {
          ref.read(pendingJobIdProvider.notifier).set(jobId);
          // 3 saniye sonra temizle (yanlışlıkla geç yönlendirmeyi önle)
          Future.delayed(const Duration(seconds: 3), () {
            if (ref.read(pendingJobIdProvider) == jobId) {
              ref.read(pendingJobIdProvider.notifier).clear();
            }
          });
        }
      });

      // Handle notification tap when app is in background
      _messageOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final jobId = message.data['jobId'];
        if (jobId != null && jobId.isNotEmpty) {
          ref.read(pendingJobIdProvider.notifier).set(jobId);
        }
      });

      // Handle notification that launched the app from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final jobId = initialMessage.data['jobId'];
        if (jobId != null && jobId.isNotEmpty) {
          // Uygulama yeni açıldığı için biraz bekle, sonra yönlendir
          Future.delayed(const Duration(milliseconds: 800), () {
            ref.read(pendingJobIdProvider.notifier).set(jobId);
          });
        }
      }

      _initialized = true;
      state = true;
    } catch (e) {
      // FCM initialization can fail silently - notifications are a bonus
      state = false;
    }
  }

  Future<void> disable() async {
    _cleanup();
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

  void _cleanup() {
    _tokenSub?.cancel();
    _messageSub?.cancel();
    _messageOpenSub?.cancel();
    _tokenSub = null;
    _messageSub = null;
    _messageOpenSub = null;
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
