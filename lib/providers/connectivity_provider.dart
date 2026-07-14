import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_stub.dart'
    // ignore: uri_has_not_been_generated
    if (dart.library.html) 'connectivity_web.dart';

// -----------------------------------------------------------------------
// Bağlantı Durumu Provider'ı (OFFLINE-01)
// Çevrimdışı olduğunda UI'a bildirim göndermek için.
// Web: window.online/offline event'leri (connectivity_web.dart)
// Mobil: connectivity_plus entegrasyonu için hazır stub (connectivity_stub.dart)
// -----------------------------------------------------------------------

/// Çevrimdışı bağlantı durumunu izleyen Riverpod Notifier.
class ConnectivityNotifier extends Notifier<bool> {
  @override
  bool build() {
    final service = ConnectivityService();
    final initial = service.isOnline;

    // Durum değişikliklerini dinle
    final sub = service.onStatusChange.listen((online) {
      if (state != online) {
        state = online;
      }
    });

    // Temizlik: provider dispose edildiğinde kaynakları serbest bırak
    ref.onDispose(() {
      sub.cancel();
      service.dispose();
    });

    return initial;
  }
}

/// Çevrimdışı bağlantı durumunu sağlayan provider.
/// `true` = çevrimiçi, `false` = çevrimdışı.
final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, bool>(
  () => ConnectivityNotifier(),
);
