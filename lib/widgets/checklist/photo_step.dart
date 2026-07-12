import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../web_safe_image.dart';

class PhotoStep extends ConsumerWidget {
  final String? url;
  final VoidCallback onTap;
  final bool isUploading;

  const PhotoStep({
    super.key,
    required this.url,
    required this.onTap,
    this.isUploading = false,
  });

  void _showFullScreen(BuildContext context, String imageUrl) {
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
                  errorBuilder: (ctx, err, stack) => const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text('Fotoğraf yüklenemedi', style: TextStyle(color: Color(0xFF90A4AE))),
                    ]),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0, right: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white, size: 28),
                    tooltip: 'İndir',
                    onPressed: () => launchUrl(Uri.parse(imageUrl)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isUploading)
          Container(
            height: 120,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A3A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 2),
                  SizedBox(height: 8),
                  Text('Fotoğraf yükleniyor...', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
                ],
              ),
            ),
          )
        else if (url != null && url!.isNotEmpty)
          InkWell(
            onTap: () => _showFullScreen(context, url!),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: WebSafeImage(
                      url: url!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: const Color(0xFF1A2A3A),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, color: Colors.red, size: 32),
                              SizedBox(height: 4),
                              Text('Fotoğraf yüklenemedi', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Tooltip(
          message: url != null && url!.isNotEmpty ? 'Fotoğrafı değiştir' : 'Galeri veya kameradan fotoğraf ekle',
          child: OutlinedButton.icon(
            onPressed: isUploading ? null : onTap,
            icon: const Icon(Icons.add_a_photo, size: 18),
            label: Text(url != null && url!.isNotEmpty ? 'Fotoğrafı Değiştir' : 'Fotoğraf Ekle', style: const TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4FC3F7),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}
