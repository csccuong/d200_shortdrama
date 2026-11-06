package com.bobdrama.bobdrama_app

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader
import android.os.Build
import android.util.AttributeSet
import android.view.animation.LinearInterpolator
import androidx.annotation.RequiresApi
import androidx.appcompat.widget.AppCompatButton

@RequiresApi(Build.VERSION_CODES.HONEYCOMB)
class ShimmerButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = androidx.appcompat.R.attr.buttonStyle
) : AppCompatButton(context, attrs, defStyleAttr) {

    private val shimmerPaint = Paint().apply {
        isAntiAlias = true
    }
    private var shimmerAnimator: ValueAnimator? = null
    private var shimmerGradient: LinearGradient? = null
    private val shaderMatrix = Matrix()
    private var shimmerTranslationX = 0f

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            clipToOutline = true
        }
        post {
            startShimmerAnimation()
        }
    }

    @RequiresApi(Build.VERSION_CODES.HONEYCOMB)
    private fun startShimmerAnimation() {
        val width = width.toFloat()
        if (width <= 0) return

        val highlightColor = 0x44FFFFFF.toInt()
        val edgeColor = 0x00FFFFFF.toInt()

        shimmerGradient = LinearGradient(
            0f, 0f, width / 2f, 0f,
            intArrayOf(edgeColor, highlightColor, edgeColor),
            floatArrayOf(0f, 0.5f, 1f),
            Shader.TileMode.CLAMP
        )
        shimmerPaint.shader = shimmerGradient

        shimmerAnimator = ValueAnimator.ofFloat(-width, width * 1.5f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = LinearInterpolator()
            addUpdateListener { animator ->
                shimmerTranslationX = animator.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val gradient = shimmerGradient ?: return
        val animator = shimmerAnimator ?: return

        if (animator.isRunning) {
            shaderMatrix.reset()
            shaderMatrix.setTranslate(shimmerTranslationX, 0f)
            shaderMatrix.preRotate(20f, width / 2f, height / 2f)
            gradient.setLocalMatrix(shaderMatrix)

            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), shimmerPaint)
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        shimmerAnimator?.cancel()
        startShimmerAnimation()
    }

    override fun onDetachedFromWindow() {
        shimmerAnimator?.cancel()
        super.onDetachedFromWindow()
    }
}
