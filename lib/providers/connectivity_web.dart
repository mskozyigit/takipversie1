// -----------------------------------------------------------------------
// Web bağlantı servisi — window.online/offline event'lerini dinler.
// dart:html kullanır, sadece web platformunda derlenir.
// -----------------------------------------------------------------------

// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

/// Web platformu için bağlantı servisi.
class ConnectivityService {
  final _controller = StreamController<bool>.broadcast();
  bool _isOnline;

  ConnectivityService() : _isOnline = html.window.navigator.onLine ?? true {
    void onOnline(html.Event _) {
      if (!_isOnline) {
        _isOnline = true;
        _controller.add(true);
      }
    }

    void onOffline(html.Event _) {
      if (_isOnline) {
        _isOnline = false;
        _controller.add(false);
      }
    }

    html.window.addEventListener('online', onOnline);
    html.window.addEventListener('offline', onOffline);
  }

  /// Mevcut çevrimiçi durumu.
  bool get isOnline => _isOnline;

  /// Çevrimiçi/çevrimdışı durum değişikliklerini dinleyen stream.
  Stream<bool> get onStatusChange => _controller.stream;

  /// Kaynakları temizle.
  void dispose() {
    _controller.close();
  }
}
