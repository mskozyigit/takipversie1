import 'package:flutter/material.dart';

/// Simple image widget for Firebase Storage images.
/// Uses Image.network which works with Firebase download URLs (they include CORS headers).
class WebSafeImage extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const WebSafeImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.shrink();

    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: errorBuilder != null
          ? (context, error, stack) => errorBuilder!(context, error, stack)
          : (context, error, stack) => const Center(
              child: Icon(Icons.broken_image, color: Colors.red),
            ),
    );
  }
}

