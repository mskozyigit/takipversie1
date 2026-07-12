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

  /// Pick, Compress and Upload image
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

    // Pick with low quality for fast upload
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: kIsWeb ? 50 : 60,
      maxWidth: 800,
    );

    if (pickedFile == null) return null;

    Uint8List uploadBytes;
    if (kIsWeb) {
      // Web: skip Dart-based compression (very slow), use picker's built-in
      uploadBytes = await pickedFile.readAsBytes();
    } else {
      // Mobile: fast client-side resize
      final original = await pickedFile.readAsBytes();
      final image = img.decodeImage(original);
      if (image == null) {
        uploadBytes = original;
      } else {
        img.Image resized = image;
        if (image.width > 800) {
          resized = img.copyResize(image, width: 800);
        }
        uploadBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
      }
    }

    final String fileName = '${isBefore ? "before" : "after"}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String path = '$orgId/jobs/$jobId/$fileName';
    
    final refStorage = _storage.ref().child(path);
    await refStorage.putData(uploadBytes, SettableMetadata(contentType: 'image/jpeg'));
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
