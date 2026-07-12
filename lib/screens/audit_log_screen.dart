import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AuditLogScreen extends ConsumerWidget {
  final String jobId;
  const AuditLogScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogsAsync = ref.watch(auditLogProvider(jobId));
    final branding = ref.watch(brandingProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('audit_log_title')),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0),
      ),
      body: auditLogsAsync.when(
        data: (logs) => logs.isEmpty
            ? Center(child: Text(l10n.translate('audit_log_empty'), style: const TextStyle(color: Color(0xFF90A4AE))))
            : RepaintBoundary(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (context, i) {
                  final log = logs[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(log.actorName, style: const TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(
                              '${log.timestamp.day}/${log.timestamp.month} ${log.timestamp.hour}:${log.timestamp.minute}',
                              style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(log.actionType, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        if (log.metadata != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            log.metadata.toString(),
                            style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        loading: () => Center(child: CircularProgressIndicator(color: context.cs.secondary)),
        error: (e, _) => Center(child: Text(l10n.translate('generic_error', {'error': '$e'}))),
      ),
    );
  }
}
