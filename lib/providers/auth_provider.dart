import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';
import 'browser_language_stub.dart'
    if (dart.library.html) 'browser_language_web.dart';
import '../models/organization.dart';

// -----------------------------------------------------------------------
// Auth State Sealed Class
// -----------------------------------------------------------------------

sealed class AuthState {
  AppUser? get appUser => null;
}

/// Kullanıcı oturum açmamış
class Unauthenticated extends AuthState {}

/// Google ile giriş yapıldı ama Firestore'da kayıt yok → Org seçimi gerekiyor
class NeedsOrg extends AuthState {
  final User firebaseUser;
  NeedsOrg(this.firebaseUser);
}

/// Onay bekliyor (pending)
class PendingApproval extends AuthState {
  final AppUser appUser;
  PendingApproval(this.appUser);
}

/// Onaylanmış Admin
class ApprovedAdmin extends AuthState {
  final AppUser appUser;
  ApprovedAdmin(this.appUser);
}

/// Onaylanmış Worker
class ApprovedWorker extends AuthState {
  final AppUser appUser;
  ApprovedWorker(this.appUser);
}

/// Hata durumu
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// -----------------------------------------------------------------------
// Dependencies
// -----------------------------------------------------------------------

final _auth = FirebaseAuth.instance;
final _firestore = FirebaseFirestore.instance;
final _googleSignIn = GoogleSignIn.instance;

// -----------------------------------------------------------------------
// Auth State Notifier
// -----------------------------------------------------------------------

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Firebase Auth değişikliklerini dinle
    _auth.authStateChanges().listen((firebaseUser) async {
      // Eğer şu an manuel bir işlem (createOrganization, joinOrganization)
      // loading state'teyse, authStateChanges'ı yoksay — işlem bitsin.
      if (state.isLoading) return;

      if (firebaseUser == null) {
        state = AsyncValue.data(Unauthenticated());
        return;
      }
      final authState = await _resolveAuthState(firebaseUser);
      state = AsyncValue.data(authState);
    });

    // Başlangıç durumu
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return Unauthenticated();
    return _resolveAuthState(firebaseUser);
  }

  /// Firebase User'ı Firestore'daki kullanıcı kaydına çevir
  Future<AuthState> _resolveAuthState(User firebaseUser) async {
    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (!doc.exists) {
        return NeedsOrg(firebaseUser);
      }

      final appUser = AppUser.fromFirestore(doc);

      switch (appUser.approvalStatus) {
        case ApprovalStatus.approved:
          if (appUser.role == UserRole.admin) return ApprovedAdmin(appUser);
          return ApprovedWorker(appUser);
        case ApprovalStatus.pending:
          return PendingApproval(appUser);
        case ApprovalStatus.rejected:
          // Reddedilen kullanıcıyı çıkış yaptır ve bilgilendir
          await signOut();
          return AuthError(ref.read(translationProvider.notifier).translate('auth_rejected'));
      }
    } catch (e) {
      return AuthError(ref.read(translationProvider.notifier).translate('auth_user_data_error', {'error': '$e'}));
    }
  }

  // -----------------------------------------------------------------------
  // AUTH-01: Google Sign-In
  // -----------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      if (kIsWeb) {
        // Web: signInWithPopup (COOP handled via Firebase Auth configuration)
        final googleProvider = GoogleAuthProvider();
        await _auth.signInWithPopup(googleProvider);
        // Hemen mevcut kullanıcıyı çözümle — authStateChanges'ı bekleme
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          final authState = await _resolveAuthState(currentUser);
          state = AsyncValue.data(authState);
        }
      } else {
        // Mobil için Google Identity Services (GIS) akışı
        final googleUser = await _googleSignIn.authenticate();
        if (googleUser == null) {
          state = AsyncValue.data(AuthError(ref.read(translationProvider.notifier).translate('auth_google_signin_cancelled')));
          return;
        }
        
        final googleAuth = googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        await _auth.signInWithCredential(credential);
      }
      // authStateChanges listener otomatik günceller
    } catch (e) {
      // Kullanıcı iptal etti veya hata oluştu
      state = AsyncValue.data(AuthError(ref.read(translationProvider.notifier).translate('auth_google_signin_failed', {'error': '$e'})));
    }
  }

  // -----------------------------------------------------------------------
  // ORG-01: Yeni Organizasyon Oluştur (Admin olarak kayıt)
  // -----------------------------------------------------------------------

  Future<void> createOrganization({
    required User firebaseUser,
    required String orgName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final joinCode = _generateJoinCode();
      final orgRef = _firestore.collection('organizations').doc();

      final org = Organization(
        id: orgRef.id,
        name: orgName,
        joinCode: joinCode,
        createdDate: DateTime.now(),
        activeLanguage: ref.read(translationProvider).value ?? 'tr',
      );

      final appUser = AppUser(
        id: firebaseUser.uid,
        organizationId: orgRef.id,
        name: firebaseUser.displayName ?? 'Admin',
        email: firebaseUser.email ?? '',
        role: UserRole.admin,
        approvalStatus: ApprovalStatus.approved, // Kurucu admin → direkt onaylı
      );

      // Firestore Security Rules bypass: Org henüz mevcut değil → kurucu bypass aktif
      final batch = _firestore.batch();
      batch.set(orgRef, org.toFirestore());
      batch.set(_firestore.collection('users').doc(firebaseUser.uid), appUser.toFirestore());
      await batch.commit();

      state = AsyncValue.data(ApprovedAdmin(appUser));
    } catch (e) {
      state = AsyncValue.data(AuthError(ref.read(translationProvider.notifier).translate('auth_org_create_failed', {'error': '$e'})));
    }
  }

  // -----------------------------------------------------------------------
  // ORG-02: Mevcut Organizasyona Katıl (Worker olarak — pending)
  // -----------------------------------------------------------------------

  Future<void> joinOrganization({
    required User firebaseUser,
    required String joinCode,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Join code ile organizasyon bul
      final query = await _firestore
          .collection('organizations')
          .where('joinCode', isEqualTo: joinCode.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        state = AsyncValue.data(AuthError(ref.read(translationProvider.notifier).translate('auth_invalid_join_code')));
        return;
      }

      final org = Organization.fromFirestore(query.docs.first);

      final appUser = AppUser(
        id: firebaseUser.uid,
        organizationId: org.id,
        name: firebaseUser.displayName ?? ref.read(translationProvider.notifier).translate('default_user_name'),
        email: firebaseUser.email ?? '',
        role: UserRole.worker,
        approvalStatus: ApprovalStatus.pending, // Yeni üye → admin onayı bekliyor
      );

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(appUser.toFirestore());

      state = AsyncValue.data(PendingApproval(appUser));
    } catch (e) {
      state = AsyncValue.data(AuthError(ref.read(translationProvider.notifier).translate('auth_join_failed', {'error': '$e'})));
    }
  }

  // -----------------------------------------------------------------------
  // ADM-03: Kullanıcı Onaylama / Reddetme
  // -----------------------------------------------------------------------

  Future<void> updateUserStatus(String userId, ApprovalStatus newStatus) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'approvalStatus': newStatus.name,
      });
    } catch (e) {
      debugPrint('Kullanıcı durumu güncellenemedi: $e');
      rethrow;
    }
  }

  Future<void> cancelJoinRequest() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).delete();
      // Google oturumu hala geçerli — kullanıcıyı NeedsOrg'a döndür, logout yapma
      state = AsyncValue.data(NeedsOrg(user));
    } catch (e) {
      debugPrint('İstek iptal edilemedi: $e');
      state = AsyncValue.data(AuthError(ref.read(translationProvider.notifier).translate('generic_error', {'error': '$e'})));
    }
  }

  Future<void> leaveOrganization() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      final appUser = AppUser.fromFirestore(userDoc);
      
      // Unassign all jobs belonging to this worker
      final jobsSnapshot = await _firestore
          .collection('jobs')
          .where('assignedWorkerId', isEqualTo: user.uid)
          .where('organizationId', isEqualTo: appUser.organizationId)
          .get();
      
      final batch = _firestore.batch();
      for (final jobDoc in jobsSnapshot.docs) {
        batch.update(jobDoc.reference, {
          'assignedWorkerId': 'unassigned',
          'assignedWorkerName': ref.read(translationProvider.notifier).translate('unassigned'),
        });
      }
      batch.delete(userDoc.reference);
      await batch.commit();
      
      await signOut();
    } catch (e) {
      debugPrint('Kurumdan ayrılamadı: $e');
      state = AsyncValue.data(AuthError(ref.read(translationProvider.notifier).translate('generic_error', {'error': '$e'})));
    }
  }

  // -----------------------------------------------------------------------
  // Sign Out
  // -----------------------------------------------------------------------

  Future<void> signOut() async {
    // Hatalardan bağımsız olarak arayüzü giriş ekranına döndürmek için AsyncValue.data(Unauthenticated())'ı en başta set ediyoruz.
    state = AsyncValue.data(Unauthenticated());
    
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Çıkış yaparken hata oluştu (önemsiz): $e');
    }
  }

  // -----------------------------------------------------------------------
  // Helper: Benzersiz 6 karakterlik join kodu üret (sadece büyük harf + rakam)
  // -----------------------------------------------------------------------

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    // 36^6 = 2.1B combinations — collision probability is negligible.
    // No Firestore check needed; two orgs generating the same code
    // at the same time is statistically impossible.
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

// -----------------------------------------------------------------------
// Provider Definitions
// -----------------------------------------------------------------------

/// Ana auth state provider
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);

/// Onay bekleyen kullanıcıları dinleyen provider
final pendingUsersProvider = StreamProvider<List<AppUser>>((ref) {
  final authState = ref.watch(authProvider).value;
  if (authState is! ApprovedAdmin) return Stream.value([]);

  return _firestore
      .collection('users')
      .where('organizationId', isEqualTo: authState.appUser.organizationId)
      .where('approvalStatus', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList());
});

/// Mevcut organizasyon bilgilerini dinleyen provider
final currentOrganizationProvider = StreamProvider<Organization?>((ref) {
  final authState = ref.watch(authProvider).value;
  String? orgId;
  
  if (authState is ApprovedAdmin) orgId = authState.appUser.organizationId;
  if (authState is ApprovedWorker) orgId = authState.appUser.organizationId;
  if (authState is PendingApproval) orgId = authState.appUser.organizationId;

  if (orgId == null) return Stream.value(null);

  return _firestore
      .collection('organizations')
      .doc(orgId)
      .snapshots()
      .map((doc) => doc.exists ? Organization.fromFirestore(doc) : null);
});

/// Mevcut AppUser'ı döndürür (null ise giriş yapılmamış)
final currentUserProvider = Provider<AppUser?>((ref) {
  // Riverpod v3: .value yerine .whenData veya switch kullan
  final asyncState = ref.watch(authProvider);
  final authState = asyncState.value;
  if (authState == null) return null;
  return switch (authState) {
    ApprovedAdmin(appUser: final user) => user,
    ApprovedWorker(appUser: final user) => user,
    PendingApproval(appUser: final user) => user,
    _ => null,
  };
});

// -----------------------------------------------------------------------
// Translation Notifier (optimized — no duplicate Firestore read, JSON cache)
// -----------------------------------------------------------------------

class TranslationNotifier extends AsyncNotifier<String> {
  Map<String, String> _map = {};
  /// Cache all loaded language maps so setLanguage() doesn't re-read assets.
  final Map<String, Map<String, String>> _jsonCache = {};

  @override
  Future<String> build() async {
    // Use org language if available, otherwise detect browser/device language.
    // On web (Android Chrome), navigator.language returns e.g. "tr-TR", "en-US", "nl-NL".
    final org = ref.watch(currentOrganizationProvider).value;
    final lang = org?.activeLanguage ?? _detectBrowserLanguage();

    await _loadLanguage(lang);
    return lang;
  }

  /// Detect browser language (web) or fall back to Turkish.
  /// On Android Chrome, navigator.language reflects the device language.
  String _detectBrowserLanguage() {
    final browserLang = getBrowserLanguage();
    if (browserLang.isNotEmpty) {
      final code = browserLang.split('-').first;
      if (['tr', 'en', 'nl'].contains(code)) return code;
    }
    return 'tr';
  }

  /// Loads a language JSON from cache or assets.
  Future<void> _loadLanguage(String lang) async {
    // Return from cache if already loaded
    if (_jsonCache.containsKey(lang)) {
      _map = _jsonCache[lang]!;
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/lang/$lang.json');
      final Map<String, dynamic> decoded = json.decode(jsonStr);
      _map = decoded.map((key, value) => MapEntry(key, value.toString()));
      _jsonCache[lang] = _map; // cache for future switches
    } catch (e) {
      debugPrint('Translation load error: $e');
      _map = {};
    }
  }

  String translate(String key, [Map<String, String>? params]) {
    String text = _map[key] ?? key;

    if (params != null) {
      params.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }

  /// ADM-02: Admin-switched language — updates Firestore + switches in-memory instantly.
  Future<void> setLanguage(String lang) async {
    final authState = ref.read(authProvider).value;
    String? orgId;
    if (authState is ApprovedAdmin) orgId = authState.appUser.organizationId;
    if (authState is ApprovedWorker) orgId = authState.appUser.organizationId;
    if (authState is PendingApproval) orgId = authState.appUser.organizationId;

    if (orgId != null) {
      // Fire-and-forget: update Firestore in background, UI switches instantly
      FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .update({'activeLanguage': lang});
    }

    // Switch language from cache (or load once) — no re-read from assets
    await _loadLanguage(lang);
    state = AsyncValue.data(lang);
  }
}

final translationProvider = AsyncNotifierProvider<TranslationNotifier, String>(
  () => TranslationNotifier(),
);

// -----------------------------------------------------------------------
// Admin → İşçi görünümü toggle (sadece admin kullanabilir)
// -----------------------------------------------------------------------

class ViewAsWorkerNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final viewAsWorkerProvider = NotifierProvider<ViewAsWorkerNotifier, bool>(
  () => ViewAsWorkerNotifier(),
);

// -----------------------------------------------------------------------
// ADM-01: Branding Provider
// -----------------------------------------------------------------------

class BrandingData {
  final bool useBranding;
  final String? logoUrl;
  final Color primaryColor;

  const BrandingData({
    this.useBranding = false,
    this.logoUrl,
    this.primaryColor = const Color(0xFF1565C0),
  });
}

final brandingProvider = Provider<BrandingData>((ref) {
  final org = ref.watch(currentOrganizationProvider).value;
  if (org == null || !org.useBranding) {
    return const BrandingData();
  }

  Color color;
  try {
    final hex = (org.primaryColorHex ?? '#1565C0').replaceFirst('#', '');
    color = Color(int.parse('FF$hex', radix: 16));
  } catch (_) {
    color = const Color(0xFF1565C0);
  }

  return BrandingData(
    useBranding: true,
    logoUrl: org.logoUrl,
    primaryColor: color,
  );
});
