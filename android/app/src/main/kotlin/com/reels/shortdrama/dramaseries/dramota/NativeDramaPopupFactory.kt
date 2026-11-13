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

class NativeDramaPopupFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {

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
        val adView =
            layoutInflater.inflate(R.layout.layout_native_drama_popup, null) as NativeAdView
        val mediaView: MediaView? = adView.findViewById(R.id.ad_media)
        val cardMedia: View? = adView.findViewById(R.id.card_media)
        val captionBar: View? = adView.findViewById(R.id.ad_caption_bar)

        cardMedia?.clipToOutline = true

        adView.headlineView = adView.findViewById(R.id.ad_headline)
        adView.bodyView = adView.findViewById(R.id.ad_body)
        adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
        adView.iconView = adView.findViewById(R.id.ad_app_icon)
        adView.advertiserView = adView.findViewById(R.id.ad_advertiser)

        (adView.headlineView as? TextView)?.text = nativeAd.headline ?: ""

        val bodyText = nativeAd.body?.trim().orEmpty()
        if (bodyText.isEmpty()) {
            adView.bodyView?.visibility = View.GONE
        } else {
            (adView.bodyView as? TextView)?.text = bodyText
            adView.bodyView?.visibility = View.VISIBLE
        }

        val iconDrawable = nativeAd.icon?.drawable
        if (iconDrawable == null) {
            adView.iconView?.visibility = View.GONE
        } else {
            (adView.iconView as? ImageView)?.setImageDrawable(iconDrawable)
            adView.iconView?.visibility = View.VISIBLE
        }

        if (bodyText.isEmpty() && iconDrawable == null) {
            captionBar?.visibility = View.GONE
        } else {
            captionBar?.visibility = View.VISIBLE
        }

        val advertiserText = nativeAd.advertiser?.trim().orEmpty()
        (adView.advertiserView as? TextView)?.text =
            if (advertiserText.isNotEmpty()) advertiserText else "✦"

        if (nativeAd.callToAction == null) {
            adView.callToActionView?.visibility = View.INVISIBLE
        } else {
            adView.callToActionView?.visibility = View.VISIBLE
            (adView.callToActionView as? Button)?.text = nativeAd.callToAction
        }

        adView.registerNativeAd(nativeAd, mediaView)
        return adView
    }
}
