import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays an image that may come either from a bundled asset (mock/offline
/// data) or a remote URL served by the backend (`/uploads/...`, `/images/...`).
///
/// Picks `Image.network` when [source] is an http(s) URL, otherwise
/// `Image.asset`, and shows a graceful placeholder if loading fails.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  bool get _isRemote => source.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return _placeholder();

    if (_isRemote) {
      return Image.network(
        source,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stack) => _placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _placeholder(child: const CircularProgressIndicator());
        },
      );
    }

    return Image.asset(
      source,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stack) => _placeholder(),
    );
  }

  Widget _placeholder({Widget? child}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.paperBlue.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: child ??
          Icon(
            Icons.image_outlined,
            color: AppColors.deepInk.withValues(alpha: 0.4),
          ),
    );
  }
}
