import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'auth_provider.dart';

final _storage = FirebaseStorage.instance;
final _picker = ImagePicker();

class MediaNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Pick, Compress and Upload image (for worker camera checklist)
  /// [source] defaults to camera, but can be gallery on mobile for reliability
  Future<String?> uploadJobPhoto({
    required String jobId,
    required bool isBefore,
    ImageSource source = ImageSource.camera,
  }) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return null;
    
    String orgId = '';
    if (authState is ApprovedAdmin) orgId = authState.appUser.organizationId;
    else if (authState is ApprovedWorker) orgId = authState.appUser.organizationId;
    else return null;

    try {
      // Pick with low quality + reduced size for fast upload
      debugPrint('[MEDIA] Opening image picker with source=$source');
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: kIsWeb ? 40 : 55,
        maxWidth: 600,
      );

      if (pickedFile == null) {
        debugPrint('[MEDIA] User cancelled picker');
        return null;
      }

      debugPrint('[MEDIA] Picked file: ${pickedFile.name}, reading bytes...');
      final bytes = await _compressImage(await pickedFile.readAsBytes());
      return await _uploadBytes(orgId: orgId, jobId: jobId, isBefore: isBefore, bytes: bytes);
    } catch (e) {
      debugPrint('[MEDIA] uploadJobPhoto failed: $e');
      rethrow;
    }
  }

  /// Upload already-picked image bytes (for admin gallery upload — no double pick)
  /// [orgId] must be a valid organization ID — throws [ArgumentError] if empty/invalid.
  Future<String?> uploadJobPhotoFromBytes({
    required String orgId,
    required String jobId,
    required Uint8List bytes,
    required bool isBefore,
  }) async {
    debugPrint('[MEDIA] uploadJobPhotoFromBytes: orgId=$orgId, jobId=$jobId, size=${bytes.length}');
    if (orgId.isEmpty || orgId == 'temp') {
      throw ArgumentError('uploadJobPhotoFromBytes: orgId cannot be empty or "temp". Organization not loaded yet.');
    }
    final compressed = await _compressImage(bytes);
    return await _uploadBytes(orgId: orgId, jobId: jobId, isBefore: isBefore, bytes: compressed);
  }

  /// Compress image bytes client-side.
  /// Falls back to original bytes if decode fails (e.g. HEIC format from iOS camera).
  Future<Uint8List> _compressImage(Uint8List original) async {
    if (kIsWeb) {
      debugPrint('[MEDIA] Web platform — skipping compression, size=${original.length} bytes');
      return original;
    }
    
    try {
      final image = img.decodeImage(original);
      if (image == null) {
        debugPrint('[MEDIA] decodeImage returned null (possible HEIC) — using original ${original.length} bytes');
        return original;
      }

      debugPrint('[MEDIA] Image decoded: ${image.width}x${image.height}, compressing...');
      img.Image resized = image;
      if (image.width > 600) {
        resized = img.copyResize(image, width: 600);
      }
      final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 65));
      debugPrint('[MEDIA] Compressed: ${original.length} → ${compressed.length} bytes');
      return compressed;
    } catch (e) {
      debugPrint('[MEDIA] Compression failed: $e — using original bytes');
      return original;
    }
  }

  /// Common upload logic
  Future<String?> _uploadBytes({
    required String orgId,
    required String jobId,
    required bool isBefore,
    required Uint8List bytes,
  }) async {
    final String fileName = '${isBefore ? "before" : "after"}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String path = '$orgId/jobs/$jobId/$fileName';

    debugPrint('[MEDIA] Uploading to Storage: path=$path, size=${bytes.length} bytes');
    final refStorage = _storage.ref().child(path);
    try {
      debugPrint('[MEDIA] putData starting...');
      await refStorage.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      debugPrint('[MEDIA] putData completed, getting download URL...');
      final downloadUrl = await refStorage.getDownloadURL();
      debugPrint('[MEDIA] Download URL obtained: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('[MEDIA] Storage ERROR [${e.code}]: ${e.message}');
      throw Exception('Storage yükleme hatası [${e.code}]: ${e.message}');
    }
  }

  /// Upload payment QR code for the organization
  Future<String?> uploadPaymentQr(String orgId) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (pickedFile == null) return null;

    final Uint8List bytes = await pickedFile.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    img.Image resized = image;
    if (image.width > 1024) {
      resized = img.copyResize(image, width: 1024);
    }
    final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 90));

    final path = '$orgId/settings/payment_qr.jpg';
    final refStorage = _storage.ref().child(path);
    await refStorage.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
    final url = await refStorage.getDownloadURL();

    // Update organization
    await FirebaseFirestore.instance.collection('organizations').doc(orgId).update({
      'paymentQrUrl': url,
    });

    return url;
  }
}

final mediaProvider = NotifierProvider<MediaNotifier, void>(() => MediaNotifier());
