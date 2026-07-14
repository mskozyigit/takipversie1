import 'package:flutter/material.dart';
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

    // 2. Google Sign-In Başlatma (Version 7.0+ require initialize)
    if (!kIsWeb) {
      await GoogleSignIn.instance.initialize();
    }

    // 3. Offline-First Yapılandırması (Section 5)
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
    // Firebase başlatılamazsa bile uygulamayı çalıştır — hata ekranı göster
    runApp(ProviderScope(child: _InitErrorApp(error: '$e')));
    return;
  }

  // 4. Riverpod ProviderScope ile sarmalama
  runApp(const ProviderScope(child: FieldServiceApp()));
}

/// Firebase başlatılamadığında gösterilen minimal hata uygulaması.
class _InitErrorApp extends StatelessWidget {
  final String error;
  const _InitErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text('Uygulama başlatılamadı',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),
                const Text('Lütfen uygulamayı kapatıp tekrar açın.',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FieldServiceApp extends StatelessWidget {
  const FieldServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Override Flutter's default red-error-screen with a user-friendly fallback.
    // Critical for web-mobile: prevents blank/red screen on unhandled exceptions.
    // Uses a Builder to access the current theme context for adaptive colors.
    ErrorWidget.builder = (details) => Builder(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          child: Container(
            color: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF5F5F5),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text('Something went wrong',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Please refresh the page to continue.',
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 13)),
                ],
              ),
            ),
          ),
        );
      },
    );

    return MaterialApp(
      title: 'Ratel Solutions FSM',
      debugShowCheckedModeBanner: false,
      // -- Sistem teması: cihaz ayarına göre otomatik açık/koyu --
      themeMode: ThemeMode.system,
      // -- Açık tema (cihaz light modda ise) --
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1565C0),
          onPrimary: Colors.white,
          secondary: Color(0xFF0288D1),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF212121),
          error: Color(0xFFD32F2F),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        extensions: const [AppThemeExt.defaultLight],
      ),
      // -- Koyu tema (cihaz dark modda ise) --
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
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
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        extensions: const [AppThemeExt.defaultDark],
      ),
      home: const AuthGate(),
    );
  }
}

/// Auth durumuna göre doğru ekranı gösteren yönlendirici
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _showSlowLoadingMessage = false;

  @override
  void initState() {
    super.initState();
    // 5 saniye sonra hala loading'deyse "yavaş bağlantı" mesajı göster
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showSlowLoadingMessage = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);

    return authAsync.when(
      loading: () => Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.secondary,
              ),
              if (_showSlowLoadingMessage) ...[
                const SizedBox(height: 24),
                const Text('Yükleniyor...',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 8),
                Text('İnternet bağlantınızı kontrol edin',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
              ],
            ],
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
