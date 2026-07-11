import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';

class CommentsSection extends ConsumerStatefulWidget {
  final String jobId;
  const CommentsSection({super.key, required this.jobId});

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);
    final commentsAsync = ref.watch(commentsProvider(widget.jobId));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: Color(0xFF4FC3F7), size: 20),
              const SizedBox(width: 8),
              Text(l10n.translate('job_notes_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: commentsAsync.when(
              data: (comments) => comments.isEmpty
                  ? const Center(child: Text('Henüz not yok', style: TextStyle(color: Color(0xFF546E7A), fontStyle: FontStyle.italic)))
                  : ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (_, i) {
                        final c = comments[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: c.authorName, style: const TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.w600, fontSize: 13)),
                                TextSpan(text: ': ${c.text}', style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 2))),
              error: (e, _) => Center(child: Text(l10n.translate('error_loading', {'error': e.toString()}), style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
            ),
          ),
          const Divider(color: Color(0xFF263238), height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Not yazın...',
                      hintStyle: TextStyle(color: Color(0xFF546E7A), fontSize: 14),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      ref.read(jobOperationsProvider.notifier).addComment(widget.jobId, _controller.text.trim());
                      _controller.clear();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
