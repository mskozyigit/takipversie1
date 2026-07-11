import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/job.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';

class PaymentStep extends StatelessWidget {
  final Job job;
  final Organization? org;
  final TranslationNotifier l10n;
  final WidgetRef ref;

  const PaymentStep({
    super.key,
    required this.job,
    this.org,
    required this.l10n,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (job.isPaid) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            '${l10n.translate('job_payment_received')} (${job.paymentMethod == 'cash' ? l10n.translate('job_payment_cash') : l10n.translate('job_payment_qr')})',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (org?.paymentQrUrl != null)
          Container(
            height: 200,
            width: 200,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: NetworkImage(org!.paymentQrUrl!), fit: BoxFit.contain),
            ),
          )
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
            if (org?.paymentQrUrl != null)
              ElevatedButton(
                onPressed: () => ref.read(jobOperationsProvider.notifier).recordPayment(job.id, 'qr'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7)),
                child: Text(l10n.translate('job_payment_qr'), style: const TextStyle(color: Color(0xFF0D1B2A))),
              ),
            if (org?.paymentQrUrl != null) const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => ref.read(jobOperationsProvider.notifier).recordPayment(job.id, 'cash'),
              child: Text(l10n.translate('job_payment_cash')),
            ),
          ],
        ),
      ],
    );
  }
}
