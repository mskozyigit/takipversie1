import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../theme/app_theme.dart';

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
          title: Text(l10n.translate('safe_checklist_item_ppe'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
          value: checklist['ppe'],
          onChanged: (val) => update('ppe', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).colorScheme.secondary,
        ),
        CheckboxListTile(
          title: Text(l10n.translate('safe_checklist_item_hazard'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
          value: checklist['hazard'],
          onChanged: (val) => update('hazard', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).colorScheme.secondary,
        ),
        CheckboxListTile(
          title: Text(l10n.translate('safe_checklist_item_lockout'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
          value: checklist['lockout'],
          onChanged: (val) => update('lockout', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 12),
        if (job.isSafetyConfirmed)
          Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(l10n.translate('safe_checklist_confirmed'), style: const TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
      ],
    );
  }
}
