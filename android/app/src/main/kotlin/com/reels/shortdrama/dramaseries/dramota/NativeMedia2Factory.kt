package com.reels.shortdrama.dramaseries.dramota

import android.os.Handler
import android.os.Looper
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.libraries.ads.mobile.sdk.nativead.MediaView
import com.google.android.libraries.ads.mobile.sdk.nativead.NativeAd
import com.google.android.libraries.ads.mobile.sdk.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class NativeMedia2Factory(private val layoutInflater: LayoutInflater) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            return buildNativeAdView(nativeAd)
        }

        var result: NativeAdView? = null
        var caughtError: Throwable? = null
        val latch = CountDownLatch(1)

        Handler(Looper.getMainLooper()).post {
            try {
                result = buildNativeAdView(nativeAd)
            } catch (t: Throwable) {
                caughtError = t
            } finally {
                latch.countDown()
            }
        }

        try {
            latch.await(5, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {}

        if (caughtError != null) {
            throw RuntimeException(caughtError)
        }

        return result ?: buildNativeAdView(nativeAd)
    }

    private fun buildNativeAdView(nativeAd: NativeAd): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.layout_native_media2, null) as NativeAdView
        val mediaView: MediaView? = adView.findViewById(R.id.ad_media)

        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        adView.iconView = adView.findViewById(R.id.ad_app_icon)

        (adView.headlineView as? TextView)?.text = nativeAd.headline

        if (nativeAd.callToAction == null) {
            adView.callToActionView?.visibility = View.INVISIBLE
        } else {
            adView.callToActionView?.visibility = View.VISIBLE
            (adView.callToActionView as? Button)?.text = nativeAd.callToAction
        }

        if (nativeAd.icon == null) {
            adView.iconView?.visibility = View.GONE
        } else {
            (adView.iconView as? ImageView)?.setImageDrawable(nativeAd.icon?.drawable)
            adView.iconView?.visibility = View.VISIBLE
        }

        adView.registerNativeAd(nativeAd, mediaView)
        return adView
    }
}
