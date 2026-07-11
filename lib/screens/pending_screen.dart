import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animasyonlu bekleyiş göstergesi
              const _PulsingIcon(),
              const SizedBox(height: 40),

              // Başlık
              Text(
                l10n.translate('pending_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Açıklama
              Text(
                l10n.translate('pending_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF90A4AE),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 48),

              // Bilgi kartları
              _InfoCard(
                icon: Icons.admin_panel_settings_outlined,
                title: l10n.translate('pending_admin_help'),
                description: l10n.translate('pending_admin_desc'),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                icon: Icons.refresh_rounded,
                title: l10n.translate('pending_auto_refresh'),
                description: l10n.translate('pending_auto_refresh_desc'),
              ),
              const SizedBox(height: 48),

              // İsteği İptal Et butonu
              TextButton(
                onPressed: () => ref.read(authProvider.notifier).cancelJoinRequest(),
                child: Text(
                  l10n.translate('pending_cancel_request'),
                  style: const TextStyle(color: Color(0xFF4FC3F7)),
                ),
              ),

              const SizedBox(height: 16),

              // Çıkış yap butonu
              OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF90A4AE),
                  side: const BorderSide(color: Color(0xFF37474F)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: Text(l10n.translate('logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

}

// -----------------------------------------------------------------------
// Pulsing animation icon
// -----------------------------------------------------------------------

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A2A3A),
          border: Border.all(
            color: const Color(0xFFFFA726).withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.hourglass_top_rounded,
          size: 50,
          color: Color(0xFFFFA726),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Info Card
// -----------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF263545)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2137),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF4FC3F7)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
