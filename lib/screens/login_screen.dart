import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final isLoading = authAsync.isLoading;

    // Hata mesajı varsa göster
    ref.listen(authProvider, (previous, next) {
      if (next.value case AuthError(:final message)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo / ikon
              const Icon(
                Icons.engineering_rounded,
                size: 80,
                color: Color(0xFF4FC3F7),
              ),
              const SizedBox(height: 24),

              // Başlık
              const Text(
                'Ratel Solutions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Field Service Management',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF90A4AE),
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 22,
                        height: 22,
                        errorBuilder: (_, _, _) => const Icon(Icons.login),
                      ),
                label: Text(
                  isLoading ? 'Giriş yapılıyor...' : 'Google ile Giriş Yap',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Alt bilgi
              const Text(
                'Giriş yaparak Kullanım Koşullarını kabul etmiş olursunuz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF546E7A),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
