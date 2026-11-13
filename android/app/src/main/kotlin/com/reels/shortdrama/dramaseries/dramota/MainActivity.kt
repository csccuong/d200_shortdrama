package com.reels.shortdrama.dramaseries.dramota

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "nativeMedia",
            NativeMediaFactory(layoutInflater)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "nativeMedia2",
            NativeMedia2Factory(layoutInflater)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "nativeFull",
            NativeFullFactory(layoutInflater)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "nativeNoMedia",
            NativeNoMediaFactory(layoutInflater)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "nativeBanner",
            NativeBannerFactory(layoutInflater)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "nativeMediaSmall",
            NativeMediaSmallFactory(layoutInflater)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "nativeDramaPopup",
            NativeDramaPopupFactory(layoutInflater)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "nativeCollap",
            NativeMediaFactory(layoutInflater)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeMedia")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeMedia2")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeFull")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeNoMedia")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeBanner")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeMediaSmall")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeDramaPopup")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "nativeCollap")
    }
}
