import 'dart:typed_data';
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

    // 1. Pick Image
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70, // Basic picker compression
    );

    if (pickedFile == null) return null;

    // 2. Client-side Compression (Resizing to max 1024px)
    final Uint8List originalBytes = await pickedFile.readAsBytes();
    final img.Image? image = img.decodeImage(originalBytes);
    
    if (image == null) return null;

    // Resize if larger than 1024px
    img.Image resized = image;
    if (image.width > 1024 || image.height > 1024) {
      resized = img.copyResize(image, width: 1024);
    }

    // Compress to JPG
    final Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));

    // 3. Upload to Firebase Storage
    // Path: organizationId/jobs/jobId/filename
    final String fileName = '${isBefore ? "before" : "after"}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String path = '$orgId/jobs/$jobId/$fileName';
    
    final refStorage = _storage.ref().child(path);
    final uploadTask = refStorage.putData(
      compressedBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}

final mediaProvider = NotifierProvider<MediaNotifier, void>(() => MediaNotifier());
