import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/login_screen.dart';
import 'screens/org_setup_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/calendar_home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Firebase Başlatma
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Redirect sonucunu işle (web için signInWithRedirect dönüşü)
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.getRedirectResult();
      } catch (_) {
        // Redirect olmamış olabilir, sessizce devam et
      }
    }

    // 3. Google Sign-In Başlatma (Version 7.0+ require initialize)
    if (!kIsWeb) {
      await GoogleSignIn.instance.initialize();
    }

    // 4. Offline-First Yapılandırması (Section 5)
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    }
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('Initialization error: $e');
      debugPrint(stack.toString());
    }
  }

  // 5. Riverpod ProviderScope ile sarmalama
  runApp(const ProviderScope(child: FieldServiceApp()));
}

class FieldServiceApp extends StatelessWidget {
  const FieldServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Override Flutter's default red-error-screen with a user-friendly fallback.
    // Critical for web-mobile: prevents blank/red screen on unhandled exceptions.
    ErrorWidget.builder = (details) => Material(
      child: Container(
        color: const Color(0xFF0D1B2A),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text('Something went wrong', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Please refresh the page to continue.', style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      ),
    );

    return MaterialApp(
      title: 'Ratel Solutions FSM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        // -- ColorScheme: tüm standart Material renkleri burada --
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1565C0),
          onPrimary: Colors.white,
          secondary: Color(0xFF4FC3F7),
          onSecondary: Color(0xFF0D1B2A),
          surface: Color(0xFF1A2A3A),
          onSurface: Colors.white,
          error: Colors.redAccent,
          onError: Colors.white,
        ),
        // -- Scaffold arka planı --
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        // -- AppBar varsayılanları --
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        // -- Uygulamaya özel renkler (status, kart, metin) --
        extensions: const [AppThemeExt.defaultDark],
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
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Text(
            l10n.translate('app_init_error', {'error': '$err'}),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
      data: (authState) {
        // TEAM-02: Initialize push notifications when user is approved
        if (authState is ApprovedAdmin || authState is ApprovedWorker) {
          Future.microtask(() => ref.read(notificationProvider.notifier).initialize());
        }

        return switch (authState) {
          Unauthenticated() => const LoginScreen(),
          NeedsOrg(firebaseUser: final user) => OrgSetupScreen(firebaseUser: user),
          PendingApproval() => const PendingScreen(),
          ApprovedAdmin(appUser: final user) => const CalendarHomeScreen(),
          ApprovedWorker(appUser: final user) => const CalendarHomeScreen(),
          AuthError(message: final msg) => Scaffold(
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
                      child: Text(l10n.translate('back_to_login'), style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        };
      },
    );
  }
}
