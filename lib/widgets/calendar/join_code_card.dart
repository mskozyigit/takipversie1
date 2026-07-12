import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class JoinCodeCard extends ConsumerWidget {
  final Organization org;
  final bool showCode;

  const JoinCodeCard({
    super.key,
    required this.org,
    required this.showCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(org.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                if (showCode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${l10n.translate('admin_join_code')}: ${org.joinCode}',
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          if (showCode)
            IconButton(
              icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.secondary, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: org.joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kod kopyalandı!'), backgroundColor: Colors.green),
                );
              },
            ),
        ],
      ),
    );
  }
}
