import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';

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
            title: Text(p['name'], style: const TextStyle(color: Colors.white)),
            trailing: Text('x${p['qty']}', style: const TextStyle(color: Color(0xFF4FC3F7))),
          )),
        OutlinedButton.icon(
          onPressed: () async {
            final nameController = TextEditingController();
            final qtyController = TextEditingController(text: '1');
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.translate('job_add_part')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Parça Adı')),
                    TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(hintText: 'Adet'),
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
