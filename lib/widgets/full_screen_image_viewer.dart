import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import 'web_safe_image.dart';
import '../theme/app_theme.dart';

/// Shared full-screen image viewer used by PhotoStep, _PhotoPreview,
/// and _DescriptionImagePreview.  Single source of truth — no more copy/paste.
class FullScreenImageViewer {
  /// Shows the image in a full-screen dialog with InteractiveViewer (zoom/pan),
  /// download and close buttons.
  static void show(BuildContext context, String imageUrl) {
    final l10n = ProviderScope.containerOf(context).read(translationProvider.notifier);
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
                  errorBuilder: (ctx, err, stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text(l10n.translate('photo_load_failed'),
                            style: TextStyle(color: ctx.appExt.textSecondary)),
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
                    tooltip: l10n.translate('button_download'),
                    onPressed: () async {
                      final uri = Uri.parse(imageUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
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
