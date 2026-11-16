import 'dart:async';
import 'package:flutter/material.dart';
import 'screen_utils.dart';

/// Lightweight floating toast rendered on the root [Overlay] so it stays
/// visible above modal bottom sheets and dialogs.
class AppToast {
  AppToast._();

  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _dismissTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    final bottomInset = AppScreenUtils.bottomSafeInset(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24.w,
        right: 24.w,
        bottom: 42.h + bottomInset,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: AppColors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSheet,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.overlayMedium,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: AppColors.primaryBright, size: 18.sp),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(duration, () {
      if (_activeEntry == entry) {
        entry.remove();
        _activeEntry = null;
      }
    });
  }
}
