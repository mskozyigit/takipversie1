import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';

class JoinCodeCard extends StatelessWidget {
  final Organization org;
  final TranslationNotifier l10n;
  final bool showCode;

  const JoinCodeCard({
    super.key,
    required this.org,
    required this.l10n,
    required this.showCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1565C0), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(org.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (showCode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${l10n.translate('admin_join_code')}: ${org.joinCode}',
                      style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          if (showCode)
            IconButton(
              icon: const Icon(Icons.copy, color: Color(0xFF4FC3F7), size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: org.joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kod kopyalandı!')),
                );
              },
            ),
        ],
      ),
    );
  }
}
