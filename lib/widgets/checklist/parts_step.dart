import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../theme/app_theme.dart';

class PartsStep extends ConsumerWidget {
  final Job job;

  const PartsStep({
    super.key,
    required this.job,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (job.usedParts != null)
          ...job.usedParts!.map((p) => ListTile(
            title: Text(p['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            trailing: Text('x${p['qty']}', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
          )),
        OutlinedButton.icon(
          onPressed: () async {
            final nameController = TextEditingController();
            final qtyController = TextEditingController(text: '1');
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(ctx).colorScheme.surface,
                title: Text(l10n.translate('job_add_part'), style: const TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Parça Adı',
                        hintStyle: const TextStyle(color: Color(0xFF90A4AE)),
                        filled: true,
                        fillColor: const Color(0xFF0D1B2A),
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Adet',
                        hintStyle: TextStyle(color: Color(0xFF90A4AE)),
                        filled: true,
                        fillColor: Color(0xFF0D1B2A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                  TextButton(
                    onPressed: () {
                      ref.read(jobOperationsProvider.notifier).addJobPart(job.id, {
                        'name': nameController.text,
                        'qty': int.tryParse(qtyController.text) ?? 1,
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Ekle'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.translate('job_add_part')),
        ),
      ],
    );
  }
}
