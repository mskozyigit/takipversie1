import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

class PhotoStep extends ConsumerWidget {
  final String? url;
  final VoidCallback onTap;

  const PhotoStep({
    super.key,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url != null)
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.camera_alt),
          label: Text(url == null ? 'Fotoğraf Çek' : 'Fotoğrafı Değiştir'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF4FC3F7)),
        ),
      ],
    );
  }
}
