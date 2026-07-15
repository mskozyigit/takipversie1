import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../web_safe_image.dart';
import '../full_screen_image_viewer.dart';

/// Reusable multi-photo picker (max 3 photos).
/// Used for before/after photos in checklist and job description images.
class MultiPhotoPicker extends ConsumerWidget {
  final List<String> photoUrls;
  final ValueChanged<List<String>> onPhotosChanged;
  final Future<String?> Function() onPickPhoto;
  final bool isUploading;
  final String label; // e.g. "Before Photo" or "After Photo"

  const MultiPhotoPicker({
    super.key,
    required this.photoUrls,
    required this.onPhotosChanged,
    required this.onPickPhoto,
    this.isUploading = false,
    this.label = '',
  });

  static const maxPhotos = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    final canAdd = photoUrls.length < maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label, style: TextStyle(color: context.appExt.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),

        // Uploading indicator
        if (isUploading)
          Container(
            height: 100,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
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
                  Text(l10n.translate('photo_uploading'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),

        // Photo grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Existing photos with delete button
            ...photoUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;
              return _PhotoTile(
                url: url,
                onTap: () => FullScreenImageViewer.show(context, url),
                onDelete: () {
                  final updated = List<String>.from(photoUrls);
                  updated.removeAt(index);
                  onPhotosChanged(updated);
                },
              );
            }),

            // Add photo button (always visible when under max)
            if (canAdd && !isUploading)
              _AddPhotoTile(
                label: l10n.translate('photo_add_button'),
                onTap: () async {
                  final url = await onPickPhoto();
                  if (url != null) {
                    // Avoid double-add: if _pickAndUploadPhoto already added
                    // the URL to the list, don't add again.
                    if (!photoUrls.contains(url)) {
                      final updated = List<String>.from(photoUrls)..add(url);
                      onPhotosChanged(updated);
                    }
                  }
                },
              ),
          ],
        ),

        // Hint: kaç fotoğraf daha eklenebileceğini göster
        if (canAdd && !isUploading)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              photoUrls.isEmpty
                  ? l10n.translate('photo_optional_hint')
                  : '${l10n.translate('photo_add_button')} (${photoUrls.length}/${MultiPhotoPicker.maxPhotos})',
              style: TextStyle(color: context.appExt.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoTile({required this.url, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.4), width: 1.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: WebSafeImage(
              url: url,
              fit: BoxFit.cover,
              cacheWidth: 200,
              errorBuilder: (context, error, stack) => Container(
                color: Theme.of(context).colorScheme.surface,
                child: const Center(child: Icon(Icons.broken_image, color: Colors.red, size: 24)),
              ),
            ),
          ),
          // Tap to view full screen
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10.5),
              ),
            ),
          ),
          // Delete button
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
          // Zoom indicator
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _AddPhotoTile({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF37474F), width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo, color: Color(0xFF4FC3F7), size: 28),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 10, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
