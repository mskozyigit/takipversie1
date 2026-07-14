// -----------------------------------------------------------------------
// Bağlantı stub'ı — web dışı platformlar için.
// Mobilde connectivity_plus entegre edilene kadar her zaman çevrimiçi döner.
// -----------------------------------------------------------------------

/// Platform-spesifik bağlantı servisi için stub.
class ConnectivityService {
  /// Mevcut çevrimiçi durumu.
  bool get isOnline => true;

  /// Çevrimiçi/çevrimdışı durum değişikliklerini dinleyen stream.
  /// Stub: hiçbir event yayınlamaz.
  Stream<bool> get onStatusChange => const Stream<bool>.empty();

  /// Kaynakları temizle.
  void dispose() {}
}
