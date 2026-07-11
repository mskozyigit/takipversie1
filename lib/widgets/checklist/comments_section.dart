import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';

class CommentsSection extends ConsumerWidget {
  final String jobId;
  final TranslationNotifier l10n;

  const CommentsSection({
    super.key,
    required this.jobId,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentsProvider(jobId));
    final controller = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('job_notes_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          commentsAsync.when(
            data: (comments) => ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, i) {
                final c = comments[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${c.authorName}: ${c.text}',
                    style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                  ),
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(l10n.translate('error_loading', {'error': e.toString()})),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: l10n.translate('job_notes_hint'),
                    hintStyle: const TextStyle(color: Color(0xFF546E7A)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF4FC3F7)),
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    ref.read(jobOperationsProvider.notifier).addComment(jobId, controller.text.trim());
                    controller.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
