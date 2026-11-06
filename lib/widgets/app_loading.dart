import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/utils/screen_utils.dart';

class AppLoading extends StatelessWidget {
  final double width;
  final double height;
  final BoxFit fit;

  const AppLoading({
    super.key,
    this.width = 100,
    this.height = 100,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/json/loading.json',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => SizedBox(
          width: 34.w,
          height: 34.w,
          child: const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.4,
          ),
        ),
      ),
    );
  }
}
