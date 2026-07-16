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
  double? _selectedAmount;

  static const _amounts = [150.0, 200.0, 250.0, 300.0];

  void _showQrDialog(double amount) {
    final l10n = ref.read(translationProvider.notifier);
    final amountKey = amount.toStringAsFixed(0);
    // Try per-amount QR first, fall back to single payment QR
    final qrUrl = widget.org?.qrPaymentUrls[amountKey] ?? widget.org?.paymentQrUrl;
    if (qrUrl == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tutar başlığı
              Text(
                '${amount.toStringAsFixed(0)} €',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.translate('payment_scan_qr'),
                style: TextStyle(color: context.appExt.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // QR Kod
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: WebSafeImage(url: qrUrl, fit: BoxFit.contain, showLoading: true),
                ),
              ),
              const SizedBox(height: 20),
              // Ödendi butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _qrSelected = true;
                      _cashSelected = false;
                      _selectedAmount = amount;
                    });
                    ref.read(jobOperationsProvider.notifier).recordPayment(widget.job.id, 'qr');
                    widget.onPaymentRecorded?.call();
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: Text(l10n.translate('payment_done')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.translate('button_cancel'), style: TextStyle(color: context.appExt.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

    // Check if any QR code is available (per-amount or single)
    final hasPerAmountQr = widget.org?.qrPaymentUrls.isNotEmpty == true;
    final hasQr = widget.org?.paymentQrUrl != null || hasPerAmountQr;

    // Highlight job's fee if it matches one of the amounts
    final jobFee = widget.job.fee;
    final jobFeeKey = jobFee != null ? jobFee.toStringAsFixed(0) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Hızlı tutar seçimi ---
        if (hasQr) ...[
          Text(
            l10n.translate('payment_select_amount'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _amounts.map((amount) {
              final amountKey = amount.toStringAsFixed(0);
              final isMatchingJobFee = jobFeeKey == amountKey;
              final hasAmountQr = widget.org?.qrPaymentUrls.containsKey(amountKey) == true;
              final isHighlighted = _selectedAmount == amount || isMatchingJobFee;

              return GestureDetector(
                onTap: hasAmountQr || hasQr ? () => _showQrDialog(amount) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? Colors.green.withOpacity(0.2)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHighlighted ? Colors.green : const Color(0xFF37474F),
                      width: isHighlighted ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMatchingJobFee && jobFee != null)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.assignment, size: 16, color: Colors.green),
                        ),
                      Text(
                        '${amount.toStringAsFixed(0)} €',
                        style: TextStyle(
                          color: isHighlighted ? Colors.green : Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // --- QR yoksa uyarı ---
        if (!hasQr)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              l10n.translate('job_payment_qr_not_available'),
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),

        // --- Ödeme yöntemi butonları ---
        Row(
          children: [
            if (hasQr)
              _PaymentButton(
                label: l10n.translate('job_payment_qr'),
                selected: _qrSelected,
                isPrimary: true,
                onToggle: () {
                  if (_qrSelected) {
                    setState(() => _qrSelected = false);
                    widget.onPaymentRecorded?.call();
                  } else {
                    setState(() {
                      _qrSelected = true;
                      _cashSelected = false;
                    });
                    ref.read(jobOperationsProvider.notifier).recordPayment(widget.job.id, 'qr');
                    widget.onPaymentRecorded?.call();
                  }
                },
              ),
            if (hasQr) const SizedBox(width: 12),
            _PaymentButton(
              label: l10n.translate('job_payment_cash'),
              selected: _cashSelected,
              isPrimary: false,
              onToggle: () {
                if (_cashSelected) {
                  setState(() => _cashSelected = false);
                  widget.onPaymentRecorded?.call();
                } else {
                  setState(() {
                    _cashSelected = true;
                    _qrSelected = false;
                  });
                  ref.read(jobOperationsProvider.notifier).recordPayment(widget.job.id, 'cash');
                  widget.onPaymentRecorded?.call();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isPrimary;
  final VoidCallback onToggle;

  const _PaymentButton({
    required this.label,
    required this.selected,
    required this.isPrimary,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton(
        onPressed: onToggle,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? Colors.green : const Color(0xFF4FC3F7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check, color: Color(0xFF0D1B2A), size: 18)),
            Text(label, style: const TextStyle(color: Color(0xFF0D1B2A))),
          ],
        ),
      );
    }
    return OutlinedButton(
      onPressed: onToggle,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Colors.green.withOpacity(0.2) : null,
        side: BorderSide(color: selected ? Colors.green : Theme.of(context).colorScheme.secondary, width: selected ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check, color: Colors.green, size: 18)),
          Text(label, style: TextStyle(color: selected ? Colors.green : Theme.of(context).colorScheme.secondary)),
        ],
      ),
    );
  }
}
