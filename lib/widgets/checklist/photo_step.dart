import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

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
            height: 200,
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
                  CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                  SizedBox(height: 12),
                  Text('Fotoğraf yükleniyor...', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                ],
              ),
            ),
          )
        else if (url != null && url!.isNotEmpty)
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFF1A2A3A),
                    child: const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),
                  );
                },
                errorBuilder: (context, error, stack) => Container(
                  color: const Color(0xFF1A2A3A),
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.red, size: 40)),
                ),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: isUploading ? null : onTap,
          icon: const Icon(Icons.camera_alt),
          label: Text(url != null && url!.isNotEmpty ? 'Fotoğrafı Değiştir' : 'Fotoğraf Çek'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4FC3F7),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }
}
