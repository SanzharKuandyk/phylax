package com.example.overlay_app

import android.app.Service
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.LruCache
import android.view.*
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import java.io.File

class OverlayService : Service() {

    companion object {
        // Configurable overlay content - will be set from Flutter
        var overlayImagePath: String? = null
        var overlayText: String = "Stay Focused!"
        var textPositionX: Float = 0.5f  // 0-1, percentage from left
        var textPositionY: Float = 0.5f  // 0-1, percentage from top
        var imageScale: Float = 1.0f
        var imageOffsetX: Float = 0.0f
        var imageOffsetY: Float = 0.0f

        // Tap to close configuration
        var tapsToClose: Int = 3  // 0 = disabled, 1-10 = tap count required
        var tapTimeoutMs: Long = 1000  // Reset tap count after this many ms

        // Image cache - LRU cache with max 10MB
        private val maxCacheSize = 10 * 1024 * 1024 // 10MB
        private val imageCache: LruCache<String, Bitmap> = object : LruCache<String, Bitmap>(maxCacheSize) {
            override fun sizeOf(key: String, bitmap: Bitmap): Int {
                return bitmap.byteCount
            }
        }

        fun getCachedBitmap(path: String): Bitmap? {
            // Check cache first
            imageCache.get(path)?.let { return it }

            // Load from disk and cache
            val file = File(path)
            if (file.exists()) {
                try {
                    val bitmap = BitmapFactory.decodeFile(path)
                    if (bitmap != null) {
                        imageCache.put(path, bitmap)
                    }
                    return bitmap
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            return null
        }

        fun clearCache() {
            imageCache.evictAll()
        }
    }

    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: View
    private var tapCount = 0
    private val tapHandler = Handler(Looper.getMainLooper())
    private val resetTapRunnable = Runnable { tapCount = 0 }

    override fun onCreate() {
        super.onCreate()

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        overlayView = createOverlayView()

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START

        windowManager.addView(overlayView, params)
    }

    private fun createOverlayView(): View {
        val container = FrameLayout(this).apply {
            setBackgroundColor(0xFF000000.toInt()) // Black background
            isClickable = true

            // Handle taps for close gesture
            setOnClickListener {
                handleTap()
            }
        }

        // Add image if path is set (using cache)
        overlayImagePath?.let { path ->
            val bitmap = getCachedBitmap(path)
            if (bitmap != null) {
                val imageView = ImageView(this).apply {
                    // CENTER_CROP matches Flutter's BoxFit.cover
                    scaleType = ImageView.ScaleType.CENTER_CROP
                    setImageBitmap(bitmap)

                    // Apply scale (scales around pivot point which defaults to center)
                    scaleX = imageScale
                    scaleY = imageScale

                    // Apply offsets
                    translationX = imageOffsetX
                    translationY = imageOffsetY
                }
                container.addView(imageView, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                ))
            }
        }

        // Add text overlay
        val textView = TextView(this).apply {
            text = overlayText
            textSize = 24f
            setTextColor(0xFFFFFFFF.toInt())
            setShadowLayer(4f, 2f, 2f, 0xFF000000.toInt())
            gravity = Gravity.CENTER
            setPadding(32, 16, 32, 16)
            setBackgroundColor(0x80000000.toInt())
        }

        val textParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        container.addView(textView, textParams)

        // Position text after layout
        container.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                container.viewTreeObserver.removeOnGlobalLayoutListener(this)
                val containerWidth = container.width
                val containerHeight = container.height

                textView.x = (containerWidth * textPositionX) - (textView.width / 2)
                textView.y = (containerHeight * textPositionY) - (textView.height / 2)
            }
        })

        // Add tap hint if taps to close is enabled
        if (tapsToClose > 0) {
            val hintView = TextView(this).apply {
                text = "Tap $tapsToClose times to close app"
                textSize = 12f
                setTextColor(0x80FFFFFF.toInt())
                gravity = Gravity.CENTER
            }
            val hintParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                bottomMargin = 48
            }
            container.addView(hintView, hintParams)
        }

        return container
    }

    private fun handleTap() {
        if (tapsToClose <= 0) return

        tapCount++
        tapHandler.removeCallbacks(resetTapRunnable)

        if (tapCount >= tapsToClose) {
            tapCount = 0
            closeBlockedApp()
        } else {
            // Reset tap count after timeout
            tapHandler.postDelayed(resetTapRunnable, tapTimeoutMs)
        }
    }

    private fun closeBlockedApp() {
        // Go to home screen (effectively closing the blocked app)
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)

        // Hide overlay since we're going home
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        tapHandler.removeCallbacks(resetTapRunnable)
        if (::overlayView.isInitialized) {
            windowManager.removeView(overlayView)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
