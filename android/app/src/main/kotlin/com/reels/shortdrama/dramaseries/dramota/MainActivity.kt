package com.reels.shortdrama.dramaseries.dramota

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyImmersiveSystemUi()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            applyImmersiveSystemUi()
        }
    }

    private fun applyImmersiveSystemUi() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller.hide(WindowInsetsCompat.Type.systemBars())
    }
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
