import 'package:flutter/material.dart';
import '../../core/utils/screen_utils.dart';
import '../../widgets/app_loading.dart';

class AdLoadingPage extends StatelessWidget {
  const AdLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.adLoadingBg,
      body: Center(
        child: AppLoading(
          width: 140.w,
          height: 140.w,
        ),
      ),
    );
  }
}
