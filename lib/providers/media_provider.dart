import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  Future<String?> uploadJobPhoto({
    required String jobId,
    required bool isBefore,
  }) async {
    final authState = ref.read(authProvider).value;
    if (authState == null) return null;
    
    String orgId = '';
    if (authState is ApprovedAdmin) orgId = authState.appUser.organizationId;
    else if (authState is ApprovedWorker) orgId = authState.appUser.organizationId;
    else return null;

    // Pick with low quality + reduced size for fast upload
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: kIsWeb ? 40 : 55,
      maxWidth: 600,
    );

    if (pickedFile == null) return null;

    final bytes = await _compressImage(await pickedFile.readAsBytes());
    return await _uploadBytes(orgId: orgId, jobId: jobId, isBefore: isBefore, bytes: bytes);
  }

  /// Upload already-picked image bytes (for admin gallery upload — no double pick)
  Future<String?> uploadJobPhotoFromBytes({
    required String orgId,
    required String jobId,
    required Uint8List bytes,
    required bool isBefore,
  }) async {
    final compressed = await _compressImage(bytes);
    return await _uploadBytes(orgId: orgId, jobId: jobId, isBefore: isBefore, bytes: compressed);
  }

  /// Compress image bytes client-side
  Future<Uint8List> _compressImage(Uint8List original) async {
    if (kIsWeb) return original; // Web: picker already compressed
    
    final image = img.decodeImage(original);
    if (image == null) return original;
    
    img.Image resized = image;
    if (image.width > 600) {
      resized = img.copyResize(image, width: 600);
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: 65));
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
    
    final refStorage = _storage.ref().child(path);
    await refStorage.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await refStorage.getDownloadURL();
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
