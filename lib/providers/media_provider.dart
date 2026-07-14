import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'auth_provider.dart';
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

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
      _log('[MEDIA] Opening image picker with source=$source');
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: kIsWeb ? 65 : 55,
        maxWidth: 600,
      );

      if (pickedFile == null) {
        _log('[MEDIA] User cancelled picker');
        return null;
      }

      _log('[MEDIA] Picked file: ${pickedFile.name}, reading bytes...');

      // Web: blob URL'lerin ömrü kısa — doğrudan FileReader ile oku
      final bytes = await _readBytesSafe(pickedFile);
      final compressed = await _compressImage(bytes);
      return await _uploadBytes(orgId: orgId, jobId: jobId, isBefore: isBefore, bytes: compressed);
    } on FirebaseException catch (e) {
      _log('[MEDIA] Storage Firebase error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      _log('[MEDIA] uploadJobPhoto failed: $e');
      rethrow;
    }
  }

  /// Web'de blob URL güvenli okuma. Mobilde normal readAsBytes.
  Future<Uint8List> _readBytesSafe(XFile file) async {
    if (kIsWeb) {
      try {
        // dart:html FileReader ile blob'dan oku — revoked sorununu aşar
        final completer = Completer<Uint8List>();
        final reader = html.FileReader();
        reader.onLoad.listen((_) {
          completer.complete(reader.result as Uint8List);
        });
        reader.onError.listen((_) {
          completer.completeError(Exception('FileReader failed: ${reader.error}'));
        });
        // Blob URL'den HttpRequest ile fetch edip Blob oluştur
        final request = html.HttpRequest();
        request.open('GET', file.path);
        request.responseType = 'blob';
        request.onLoad.listen((_) {
          reader.readAsArrayBuffer(request.response as html.Blob);
        });
        request.onError.listen((_) {
          completer.completeError(Exception('HTTP fetch failed for blob URL'));
        });
        request.send();
        return await completer.future;
      } catch (_) {
        // Fallback: normal readAsBytes dene
        return await file.readAsBytes();
      }
    }
    return await file.readAsBytes();
  }

  /// Upload already-picked image bytes (for admin gallery upload — no double pick)
  /// [orgId] must be a valid organization ID — throws [ArgumentError] if empty/invalid.
  Future<String?> uploadJobPhotoFromBytes({
    required String orgId,
    required String jobId,
    required Uint8List bytes,
    required bool isBefore,
  }) async {
    _log('[MEDIA] uploadJobPhotoFromBytes: orgId=$orgId, jobId=$jobId, size=${bytes.length}');
    if (orgId.isEmpty || orgId == 'temp') {
      throw ArgumentError('uploadJobPhotoFromBytes: orgId is empty or "temp" — organization not loaded yet.');
    }
    final compressed = await _compressImage(bytes);
    return await _uploadBytes(orgId: orgId, jobId: jobId, isBefore: isBefore, bytes: compressed);
  }

  /// Compress image bytes client-side.
  /// Falls back to original bytes if decode fails (e.g. HEIC format from iOS camera).
  Future<Uint8List> _compressImage(Uint8List original) async {
    if (kIsWeb) {
      _log('[MEDIA] Web platform — skipping compression, size=${original.length} bytes');
      return original;
    }
    
    try {
      final image = img.decodeImage(original);
      if (image == null) {
        _log('[MEDIA] decodeImage returned null (possible HEIC) — using original ${original.length} bytes');
        return original;
      }

      _log('[MEDIA] Image decoded: ${image.width}x${image.height}, compressing...');
      img.Image resized = image;
      if (image.width > 600) {
        resized = img.copyResize(image, width: 600);
      }
      final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 65));
      _log('[MEDIA] Compressed: ${original.length} → ${compressed.length} bytes');
      return compressed;
    } catch (e) {
      _log('[MEDIA] Compression failed: $e — using original bytes');
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

    _log('[MEDIA] Uploading to Storage: path=$path, size=${bytes.length} bytes');
    final refStorage = _storage.ref().child(path);
    try {
      _log('[MEDIA] putData starting...');
      await refStorage.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      _log('[MEDIA] putData completed, getting download URL...');
      final downloadUrl = await refStorage.getDownloadURL();
      _log('[MEDIA] Download URL obtained: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      _log('[MEDIA] Storage ERROR [${e.code}]: ${e.message}');
      throw Exception('Storage upload error [${e.code}]: ${e.message}');
    }
  }

  /// Upload payment QR code for the organization
  Future<String?> uploadPaymentQr(String orgId) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (pickedFile == null) return null;

    final Uint8List bytes = await _readBytesSafe(pickedFile);
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
