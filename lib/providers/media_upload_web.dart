// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:image_picker/image_picker.dart';

/// Web implementation: uses FileReader + HttpRequest for blob URL safety.
Future<Uint8List> readBytesSafe(XFile file) async {
  try {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      completer.complete(reader.result as Uint8List);
    });
    reader.onError.listen((_) {
      completer.completeError(Exception('FileReader failed: ${reader.error}'));
    });
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
    return await file.readAsBytes();
  }
}
