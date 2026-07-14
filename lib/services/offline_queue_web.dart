// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

// -----------------------------------------------------------------------
// Offline Queue Web — localStorage tabanlı kuyruk.
// -----------------------------------------------------------------------

const _storageKey = 'takip_offline_queue';

class OfflineQueueStorage {
  /// Kuyruğa bir işlem ekle. Benzersiz ID döner.
  Future<String> add(Map<String, dynamic> operation) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final entry = {'id': id, 'timestamp': DateTime.now().toIso8601String(), ...operation};
    final queue = await _readQueue();
    queue.add(entry);
    await _writeQueue(queue);
    return id;
  }

  /// Tüm bekleyen işlemleri (en eskiden en yeniye) döndür.
  Future<List<Map<String, dynamic>>> getAll() async {
    return await _readQueue();
  }

  /// Belirtilen ID'li işlemi kuyruktan sil.
  Future<void> remove(String id) async {
    final queue = await _readQueue();
    queue.removeWhere((e) => e['id'] == id);
    await _writeQueue(queue);
  }

  /// Bekleyen işlem sayısı.
  Future<int> count() async {
    final queue = await _readQueue();
    return queue.length;
  }

  /// Tüm kuyruğu temizle.
  Future<void> clear() async {
    html.window.localStorage.remove(_storageKey);
  }

  // -------- Private --------

  Future<List<Map<String, dynamic>>> _readQueue() async {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = json.decode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    try {
      html.window.localStorage[_storageKey] = json.encode(queue);
    } catch (_) {
      // localStorage dolu olabilir — sessizce devam et
    }
  }
}
