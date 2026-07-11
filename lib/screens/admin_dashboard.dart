import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/app_user.dart';

class AdminDashboard extends ConsumerWidget {
  final AppUser adminUser;

  const AdminDashboard({super.key, required this.adminUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingUsersAsync = ref.watch(pendingUsersProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('${l10n.translate('admin_panel_title')} — ${adminUser.name}'),
        backgroundColor: const Color(0xFF1565C0),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.translate('admin_pending_users'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: pendingUsersAsync.when(
              data: (users) => users.isEmpty
                  ? Center(
                      child: Text(
                        l10n.translate('admin_no_pending'),
                        style: const TextStyle(color: Color(0xFF90A4AE)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Card(
                          color: const Color(0xFF1A2A3A),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(user.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(user.email, style: const TextStyle(color: Color(0xFF90A4AE))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => ref.read(authProvider.notifier).updateUserStatus(user.id, ApprovalStatus.rejected),
                                  child: Text(l10n.translate('admin_reject'), style: const TextStyle(color: Colors.redAccent)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => ref.read(authProvider.notifier).updateUserStatus(user.id, ApprovalStatus.approved),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: Text(l10n.translate('admin_approve')),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }
}
