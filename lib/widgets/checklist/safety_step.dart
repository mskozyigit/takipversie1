import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';

class SafetyStep extends ConsumerWidget {
  final Job job;

  const SafetyStep({super.key, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    final checklist = job.safetyChecklist ?? {
      'ppe': false,
      'hazard': false,
      'lockout': false,
    };

    void update(String key, bool value) {
      final next = Map<String, bool>.from(checklist);
      next[key] = value;
      ref.read(jobOperationsProvider.notifier).updateSafetyChecklist(job.id, next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(l10n.translate('safe_checklist_item_ppe'), style: const TextStyle(color: Colors.white, fontSize: 14)),
          value: checklist['ppe'],
          onChanged: (val) => update('ppe', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF4FC3F7),
        ),
        CheckboxListTile(
          title: Text(l10n.translate('safe_checklist_item_hazard'), style: const TextStyle(color: Colors.white, fontSize: 14)),
          value: checklist['hazard'],
          onChanged: (val) => update('hazard', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF4FC3F7),
        ),
        CheckboxListTile(
          title: Text(l10n.translate('safe_checklist_item_lockout'), style: const TextStyle(color: Colors.white, fontSize: 14)),
          value: checklist['lockout'],
          onChanged: (val) => update('lockout', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF4FC3F7),
        ),
        const SizedBox(height: 12),
        if (job.isSafetyConfirmed)
          const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text('Güvenlik adımları onaylandı.', style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
      ],
    );
  }
}
