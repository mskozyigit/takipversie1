import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/org_setup_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/calendar_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase Başlatma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Google Sign-In Başlatma (Version 7.0+ require initialize)
  await GoogleSignIn.instance.initialize();

  // 3. Offline-First Yapılandırması (Section 5)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // 3. Riverpod ProviderScope ile sarmalama
  runApp(const ProviderScope(child: FieldServiceApp()));
}

class FieldServiceApp extends StatelessWidget {
  const FieldServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ratel Solutions FSM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

/// Auth durumuna göre doğru ekranı gösteren yönlendirici
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final l10n = ref.read(translationProvider.notifier);

    return authAsync.when(
      // Yükleniyor
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0D1B2A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
        ),
      ),

      // Hata durumu
      error: (err, _) => Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Center(
          child: Text(
            'Uygulama başlatılamadı: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),

      // Başarılı durum — AuthState türüne göre yönlendirme
      data: (authState) => switch (authState) {
        // Giriş yapılmamış → Login ekranı
        Unauthenticated() => const LoginScreen(),

        // Firebase'de hesap var ama Firestore'da kayıt yok → Org kurulumu
        NeedsOrg(firebaseUser: final user) => OrgSetupScreen(firebaseUser: user),

        // Onay bekliyor → Pending ekranı
        PendingApproval() => const PendingScreen(),

        // Onaylanmış Admin → Takvimli Ana Ekran
        ApprovedAdmin(appUser: final user) => const CalendarHomeScreen(),

        // Onaylanmış Worker → Takvimli Ana Ekran
        ApprovedWorker(appUser: final user) => const CalendarHomeScreen(),

        // Hata durumu (auth state'den dönen)
        AuthError(message: final msg) => Scaffold(
            backgroundColor: const Color(0xFF0D1B2A),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.read(authProvider.notifier).signOut(),
                      child: Text(l10n.translate('back_to_login')),
                    ),
                  ],
                ),
              ),
            ),
          ),
      },
    );
  }
}
