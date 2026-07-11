import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';
import '../models/organization.dart';

// -----------------------------------------------------------------------
// Auth State Sealed Class
// -----------------------------------------------------------------------

sealed class AuthState {}

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
final _googleSignIn = GoogleSignIn();

// -----------------------------------------------------------------------
// Auth State Notifier
// -----------------------------------------------------------------------

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Firebase Auth değişikliklerini dinle
    _auth.authStateChanges().listen((firebaseUser) async {
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
          return AuthError('Hesabınız reddedildi. Lütfen organizasyon yöneticisiyle iletişime geçin.');
      }
    } catch (e) {
      return AuthError('Kullanıcı verisi alınamadı: $e');
    }
  }

  // -----------------------------------------------------------------------
  // AUTH-01: Google Sign-In
  // -----------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      if (kIsWeb) {
        // Web için Firebase Auth popup (en kararlı yöntem)
        final googleProvider = GoogleAuthProvider();
        await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobil için Google Identity Services (GIS) akışı
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          state = AsyncValue.data(Unauthenticated());
          return;
        }
        
        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        await _auth.signInWithCredential(credential);
      }
      // authStateChanges listener otomatik günceller
    } catch (e) {
      // Kullanıcı iptal etti veya hata oluştu
      state = AsyncValue.data(AuthError('Google girişi başarısız: $e'));
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
      state = AsyncValue.data(AuthError('Organizasyon oluşturulamadı: $e'));
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
        state = AsyncValue.data(AuthError('Geçersiz katılım kodu. Lütfen tekrar deneyin.'));
        return;
      }

      final org = Organization.fromFirestore(query.docs.first);

      final appUser = AppUser(
        id: firebaseUser.uid,
        organizationId: org.id,
        name: firebaseUser.displayName ?? 'Kullanıcı',
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
      state = AsyncValue.data(AuthError('Organizasyona katılınamadı: $e'));
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
    }
  }

  Future<void> cancelJoinRequest() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).delete();
      state = AsyncValue.data(Unauthenticated());
    } catch (e) {
      debugPrint('İstek iptal edilemedi: $e');
    }
  }

  Future<void> leaveOrganization() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Önce dokümanı siliyoruz
      await _firestore.collection('users').doc(user.uid).delete();
      // Sonra güvenli çıkış yapıyoruz (bu bizi login ekranına atar, tekrar girince kurulum ekranı gelir)
      await signOut();
    } catch (e) {
      debugPrint('Kurumdan ayrılamadı: $e');
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
// Translation Notifier
// -----------------------------------------------------------------------

class TranslationNotifier extends AsyncNotifier<String> {
  Map<String, String> _map = {};

  @override
  Future<String> build() async {
    // Auth state'i dinle
    final authState = ref.watch(authProvider).value;

    String lang = 'tr';
    if (authState is ApprovedAdmin) {
      lang = await _getOrgLanguage(authState.appUser.organizationId);
    } else if (authState is ApprovedWorker) {
      lang = await _getOrgLanguage(authState.appUser.organizationId);
    } else if (authState is PendingApproval) {
      lang = await _getOrgLanguage(authState.appUser.organizationId);
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/lang/$lang.json');
      final Map<String, dynamic> decoded = json.decode(jsonStr);
      _map = decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      debugPrint('Translation load error: $e');
      _map = {};
    }

    return lang;
  }

  Future<String> _getOrgLanguage(String orgId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      
      if (doc.exists) {
        return doc.data()?['activeLanguage'] ?? 'tr';
      }
    } catch (_) {}
    return 'tr';
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
}

final translationProvider = AsyncNotifierProvider<TranslationNotifier, String>(
  () => TranslationNotifier(),
);
