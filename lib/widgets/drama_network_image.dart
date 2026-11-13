import 'package:flutter/material.dart';

import '../core/di/injection.dart';
import '../core/startup/app_startup_coordinator.dart';
import '../core/theme/app_colors.dart';

/// Displays a drama poster or cover image loaded over HTTP with dark placeholder
/// and error fallback, resolving relative paths when needed.
class DramaNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const DramaNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  static String resolveUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (getIt.isRegistered<AppStartupCoordinator>()) {
      return getIt<AppStartupCoordinator>().resolveMediaUrl(trimmed);
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://api.dramota.com${trimmed.startsWith('/') ? trimmed : '/$trimmed'}';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveUrl(imageUrl);

    Widget content;
    if (resolved.isEmpty) {
      content = _fallback();
    } else {
      content = Image.network(
        resolved,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: AppColors.surfaceCard,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textWhite24,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceCard,
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: AppColors.textWhite24,
          size: 28,
        ),
      ),
    );
  }
}
