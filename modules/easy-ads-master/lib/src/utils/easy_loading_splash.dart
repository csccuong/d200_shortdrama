import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class EasyLoadingSplash extends StatelessWidget {
  final Widget? customSplash;
  final String? message;

  const EasyLoadingSplash({Key? key, this.customSplash, this.message})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF515151);

    if (customSplash != null) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(body: customSplash!),
      );
    }

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 50,
                width: 50,
                child: SpinKitThreeBounce(
                  color: textColor,
                  size: 30.0,
                ),
              ),
              const SizedBox(height: 8),
              if (message != null)
                Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
