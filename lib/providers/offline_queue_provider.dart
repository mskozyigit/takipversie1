import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'connectivity_provider.dart';
import 'job_provider.dart';
import 'auth_provider.dart';

// -----------------------------------------------------------------------
// Offline Queue Provider — çevrimdışı işlem kuyruğu yönetimi
// -----------------------------------------------------------------------

/// Bekleyen işlem sayısını ve senkronizasyon durumunu tutar.
class OfflineQueueNotifier extends Notifier<int> {
  final _storage = OfflineQueueStorage();
  bool _isSyncing = false;

  @override
  int build() {
    // Bağlantı geri gelince otomatik senkronize et
    ref.listen(connectivityProvider, (prev, next) {
      if (next && !(prev ?? false) && !_isSyncing) {
        _processQueue();
      }
    });

    // İlk açılışta kuyruk sayısını al ve çevrimiçiysek senkronize et
    _init();
    return 0;
  }

  Future<void> _init() async {
    state = await _storage.count();
    if (ref.read(connectivityProvider) && !_isSyncing) {
      _processQueue();
    }
  }

  /// Yeni bir işlemi kuyruğa ekle.
  Future<void> enqueue(Map<String, dynamic> operation) async {
    await _storage.add(operation);
    state = await _storage.count();
  }

  /// Kuyruktaki tüm işlemleri sırayla işle.
  Future<void> _processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final queue = await _storage.getAll();
      if (queue.isEmpty) {
        _isSyncing = false;
        return;
      }

      for (final entry in queue) {
        final success = await _executeOperation(entry);
        if (success) {
          await _storage.remove(entry['id'] as String);
        } else {
          // Başarısız olanı atla, sonrakini dene
          break; // Bağlantı sorunu varsa dur
        }
      }

      state = await _storage.count();
    } finally {
      _isSyncing = false;
    }
  }

  /// Tek bir işlemi Firestore'a uygula.
  Future<bool> _executeOperation(Map<String, dynamic> op) async {
    final type = op['type'] as String?;
    if (type == null) return true; // Bilinmeyen tip, kuyruktan sil

    try {
      switch (type) {
        case 'createJob':
          return await _syncCreateJob(op['data'] as Map<String, dynamic>);
        default:
          return true; // Desteklenmeyen tip, sessizce atla
      }
    } catch (_) {
      return false; // Başarısız, tekrar dene
    }
  }

  /// Kuyruktaki job oluşturma işlemini Firestore'a yaz.
  Future<bool> _syncCreateJob(Map<String, dynamic> data) async {
    final authState = ref.read(authProvider).value;
    if (authState?.appUser == null) return false;

    try {
      await ref.read(jobOperationsProvider.notifier).createJob(
        title: data['title'] as String,
        description: data['description'] as String? ?? '',
        assignedWorkerId: data['assignedWorkerId'] as String,
        assignedWorkerName: data['assignedWorkerName'] as String,
        address: data['address'] as String,
        customerName: data['customerName'] as String?,
        customerPhone: data['customerPhone'] as String?,
        scheduledDate: DateTime.parse(data['scheduledDate'] as String),
        missionNumber: data['missionNumber'] as String?,
        distanceKm: (data['distanceKm'] as num?)?.toDouble(),
        fee: (data['fee'] as num?)?.toDouble(),
        durationHours: (data['durationHours'] as int?) ?? 2,
        descriptionBlocks: (data['descriptionBlocks'] as List?)?.cast<String>() ?? [],
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Bekleyen offline işlem sayısını sağlayan provider.
final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, int>(
  () => OfflineQueueNotifier(),
);
