import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_safe_image.dart';

/// Shared full-screen image viewer used by PhotoStep, _PhotoPreview,
/// and _DescriptionImagePreview.  Single source of truth — no more copy/paste.
class FullScreenImageViewer {
  /// Shows the image in a full-screen dialog with InteractiveViewer (zoom/pan),
  /// download and close buttons.
  static void show(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: WebSafeImage(
                  url: imageUrl,
                  fit: BoxFit.contain,
                  cacheWidth: null,
                  errorBuilder: (ctx, err, stack) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text('Fotoğraf yüklenemedi',
                            style: TextStyle(color: Color(0xFF90A4AE))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download,
                        color: Colors.white, size: 28),
                    tooltip: 'İndir',
                    onPressed: () => launchUrl(Uri.parse(imageUrl)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
