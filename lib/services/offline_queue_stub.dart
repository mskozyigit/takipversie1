// -----------------------------------------------------------------------
// Offline Queue Stub — web dışı platformlar için.
// Mobilde SharedPreferences veya Hive ile değiştirilebilir.
// -----------------------------------------------------------------------

/// Platform-spesifik offline kuyruk servisi için stub.
class OfflineQueueStorage {
  /// Kuyruğa bir işlem ekle. ID döner.
  Future<String> add(Map<String, dynamic> operation) async => '';

  /// Tüm bekleyen işlemleri döndür.
  Future<List<Map<String, dynamic>>> getAll() async => [];

  /// Belirtilen ID'li işlemi kuyruktan sil.
  Future<void> remove(String id) async {}

  /// Bekleyen işlem sayısı.
  Future<int> count() async => 0;

  /// Tüm kuyruğu temizle.
  Future<void> clear() async {}
}
