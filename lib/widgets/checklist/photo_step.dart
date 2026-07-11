import 'package:flutter/material.dart';
import '../../providers/auth_provider.dart';

class PhotoStep extends StatelessWidget {
  final String? url;
  final VoidCallback onTap;
  final TranslationNotifier l10n;

  const PhotoStep({
    super.key,
    required this.url,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
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
