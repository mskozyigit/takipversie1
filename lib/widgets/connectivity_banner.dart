import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_queue_provider.dart';

/// Çevrimdışı olduğunda veya bekleyen offline işlemler olduğunda
/// ekranın üstünde görünen uyarı banner'ı.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final pendingCount = ref.watch(offlineQueueProvider);

    // Çevrimiçi ve bekleyen işlem yok → gösterme
    if (isOnline && pendingCount == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Offline ise turuncu, sync bekliyorsa mavi
    final bgColor = isOnline
        ? (isDark ? const Color(0xFF0D47A1) : const Color(0xFFBBDEFB))
        : (isDark ? Colors.orange.shade900 : Colors.orange.shade100);
    final fgColor = isOnline
        ? (isDark ? Colors.blue.shade100 : const Color(0xFF0D47A1))
        : (isDark ? Colors.orange.shade200 : Colors.orange.shade800);
    final icon = isOnline ? Icons.sync_rounded : Icons.wifi_off_rounded;
    final message = isOnline
        ? '$pendingCount işlem senkronize ediliyor...'
        : 'İnternet bağlantısı yok. $pendingCount işlem bağlantı sağlandığında gönderilecek.';

    return Material(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: bgColor,
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(icon, size: 20, color: fgColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 13, color: fgColor),
                ),
              ),
              if (isOnline && pendingCount > 0)
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
