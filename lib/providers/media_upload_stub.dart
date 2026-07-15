import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Non-web implementation: reads file bytes directly.
Future<Uint8List> readBytesSafe(XFile file) async {
  return await file.readAsBytes();
}
