import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/web_safe_image.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final isLoading = authAsync.isLoading;
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);

    // Hata mesajı varsa göster
    ref.listen(authProvider, (previous, next) {
      if (next.value case AuthError(:final message)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / ikon — ADM-01: Branding logo desteği
              _BrandingLogo(),
              const SizedBox(height: 24),

              // Başlık
              Text(
                l10n.translate('login_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('login_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.appExt.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 64),

              // Google Sign-In butonu
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => ref.read(authProvider.notifier).signInWithGoogle(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                icon: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      )
                    : Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 22,
                        height: 22,
                        errorBuilder: (context, error, stack) => const Icon(Icons.login),
                      ),
                label: Text(
                  isLoading ? l10n.translate('login_logging_in') : l10n.translate('login_google_button'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Alt bilgi
              Text(
                l10n.translate('login_terms'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.appExt.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),      ),    );
  }
}

// ADM-01: Branding-aware logo widget
class _BrandingLogo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);

    if (branding.useBranding && branding.logoUrl != null && branding.logoUrl!.isNotEmpty) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: WebSafeImage(
            url: branding.logoUrl!,
            height: 80,
            width: 200,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.engineering_rounded,
              size: 80,
              color: Color(0xFF4FC3F7),
            ),
          ),
        ),
      );
    }

    return Icon(
      Icons.engineering_rounded,
      size: 80,
      color: Theme.of(context).colorScheme.secondary,
    );
  }
}
