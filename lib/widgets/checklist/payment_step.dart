import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../theme/app_theme.dart';
import '../web_safe_image.dart';

class PaymentStep extends ConsumerStatefulWidget {
  final Job job;
  final Organization? org;
  final VoidCallback? onPaymentRecorded;

  const PaymentStep({
    super.key,
    required this.job,
    this.org,
    this.onPaymentRecorded,
  });

  @override
  ConsumerState<PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends ConsumerState<PaymentStep> {
  bool _cashSelected = false;
  bool _qrSelected = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);
    if (widget.job.isPaid) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            '${l10n.translate('job_payment_received')} (${widget.job.paymentMethod == 'cash' ? l10n.translate('job_payment_cash') : l10n.translate('job_payment_qr')})',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.org?.paymentQrUrl != null) ...[
          Container(
            height: 200,
            width: 200,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: WebSafeImage(url: widget.org!.paymentQrUrl!, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.translate('payment_qr_instruction'),
              style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ]
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              l10n.translate('job_payment_qr_not_available'),
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        Row(
          children: [
            if (widget.org?.paymentQrUrl != null)
              ElevatedButton(
                onPressed: (_qrSelected || _cashSelected) ? null : () async {
                  setState(() => _qrSelected = true);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Theme.of(ctx).colorScheme.surface,
                      title: Text(l10n.translate('job_payment_qr'), style: const TextStyle(color: Colors.white)),
                      content: Text(l10n.translate('payment_qr_confirm'), style: const TextStyle(color: Color(0xFF90A4AE))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('button_cancel'))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('job_payment_received'), style: const TextStyle(color: Colors.green))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(jobOperationsProvider.notifier).recordPayment(widget.job.id, 'qr');
                    widget.onPaymentRecorded?.call();
                  } else {
                    setState(() => _qrSelected = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _qrSelected ? Colors.green : const Color(0xFF4FC3F7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_qrSelected) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check, color: Color(0xFF0D1B2A), size: 18)),
                    Text(l10n.translate('job_payment_qr'), style: const TextStyle(color: Color(0xFF0D1B2A))),
                  ],
                ),
              ),
            if (widget.org?.paymentQrUrl != null) const SizedBox(width: 12),
            OutlinedButton(
              onPressed: (_qrSelected || _cashSelected) ? null : () async {
                setState(() => _cashSelected = true);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Theme.of(ctx).colorScheme.surface,
                    title: Text(l10n.translate('job_payment_cash'), style: const TextStyle(color: Colors.white)),
                      content: Text(l10n.translate('payment_cash_confirm'), style: const TextStyle(color: Color(0xFF90A4AE))),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('button_cancel'))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('payment_method_cash'), style: const TextStyle(color: Colors.green))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(jobOperationsProvider.notifier).recordPayment(widget.job.id, 'cash');
                  widget.onPaymentRecorded?.call();
                } else {
                  setState(() => _cashSelected = false);
                }
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: _cashSelected ? Colors.green.withOpacity(0.2) : null,
                side: BorderSide(color: _cashSelected ? Colors.green : Theme.of(context).colorScheme.secondary, width: _cashSelected ? 2 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cashSelected) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check, color: Colors.green, size: 18)),
                  Text(l10n.translate('job_payment_cash'), style: TextStyle(color: _cashSelected ? Colors.green : Theme.of(context).colorScheme.secondary)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
