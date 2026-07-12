import 'package:flutter/material.dart';

/// Optimized image widget for Firebase Storage images.
/// - Decodes at thumbnail resolution (cacheWidth) to reduce memory & bandwidth
/// - Shows shimmer loading indicator while fetching
/// - Falls back to error icon if image fails to load
class WebSafeImage extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool showLoading;

  const WebSafeImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit,
    this.errorBuilder,
    this.cacheWidth = 400,
    this.cacheHeight,
    this.showLoading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.shrink();

    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      loadingBuilder: showLoading
          ? (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              final total = loadingProgress.expectedTotalBytes;
              final progress = total != null
                  ? loadingProgress.cumulativeBytesLoaded / total
                  : null;
              return Container(
                height: height,
                width: width,
                color: const Color(0xFF1A2A3A),
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress,
                    color: const Color(0xFF4FC3F7),
                    strokeWidth: 2,
                  ),
                ),
              );
            }
          : null,
      errorBuilder: errorBuilder != null
          ? (context, error, stack) => errorBuilder!(context, error, stack)
          : (context, error, stack) => const Center(
              child: Icon(Icons.broken_image, color: Colors.red),
            ),
    );
  }
}

