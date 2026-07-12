import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../web_safe_image.dart';
import '../full_screen_image_viewer.dart';

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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary, strokeWidth: 2),
                  const SizedBox(height: 8),
                  Text('Fotoğraf yükleniyor...', style: TextStyle(color: context.appExt.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          )
        else if (url != null && url!.isNotEmpty)
          InkWell(
            onTap: () => FullScreenImageViewer.show(context, url!),
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
                        color: Theme.of(context).colorScheme.surface,
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
