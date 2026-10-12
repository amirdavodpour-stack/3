package com.hope.marketplace

import android.graphics.Bitmap
import android.graphics.Rect
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.Choreographer
import android.view.PixelCopy
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterImageView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val HOPE_SCREENSHOT_CHANNEL = "hope.runtime/screenshot"
        private const val INTEGRATION_TEST_CHANNEL = "plugins.flutter.io/integration_test"
        private const val HOPE_SCREENSHOT_FRAME_TIMEOUT_MS = 15_000L
        private const val HOPE_SCREENSHOT_FRAME_RETRY_INTERVAL_MS = 250L
    }

    private var hopeScreenshotThread: HandlerThread? = null
    private var hopeScreenshotBackgroundHandler: Handler? = null
    private var hopeScreenshotMainHandler: Handler? = null
    private val hopeScreenshotInProgress = AtomicBoolean(false)
    private val hopeScreenshotFrameCaptured = AtomicBoolean(false)
    private val hopeScreenshotResultCompleted = AtomicBoolean(false)
    private var hopeScreenshotFrameRetryRunnable: Runnable? = null
    private var hopeScreenshotTimeoutRunnable: Runnable? = null

    /**
     * flutter drive supplies the requested capture route via the Android Intent.
     *
     * The runtime evidence APK is a debug build, so we explicitly consume that
     * launch extra here. Release builds continue to use FlutterActivity's
     * default, security-hardened route handling.
     */
    override fun getInitialRoute(): String? {
        return if (BuildConfig.DEBUG) {
            intent?.getStringExtra("route") ?: super.getInitialRoute()
        } else {
            super.getInitialRoute()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!BuildConfig.DEBUG) {
            return
        }

        hopeScreenshotMainHandler = Handler(Looper.getMainLooper())
        hopeScreenshotThread = HandlerThread("hope-runtime-screenshot").also { it.start() }
        hopeScreenshotBackgroundHandler = Handler(hopeScreenshotThread!!.looper)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HOPE_SCREENSHOT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureScreenshot" -> captureHopeScreenshot(
                    result,
                    call.argument<Boolean>("forceFreshFrame") ?: false,
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        clearHopeScreenshotCaptureWatchdogs()
        hopeScreenshotBackgroundHandler?.post {
            hopeScreenshotThread?.quitSafely()
        }
        hopeScreenshotThread = null
        hopeScreenshotBackgroundHandler = null
        hopeScreenshotMainHandler = null
        super.onDestroy()
    }

    private fun captureHopeScreenshot(
        result: MethodChannel.Result,
        forceFreshFrame: Boolean = false,
    ) {
        if (!hopeScreenshotInProgress.compareAndSet(false, true)) {
            result.error(
                "CAPTURE_IN_PROGRESS",
                "Another HOPE runtime screenshot is already being captured.",
                null,
            )
            return
        }

        hopeScreenshotResultCompleted.set(false)
        hopeScreenshotFrameCaptured.set(false)

        val flutterView = findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)
        val imageView: FlutterImageView? = flutterView?.getCurrentImageSurface()
        val imageReader = imageView?.getImageReader()
        val mainHandler = hopeScreenshotMainHandler
        val backgroundHandler = hopeScreenshotBackgroundHandler

        if (flutterView == null || imageView == null || imageReader == null ||
            mainHandler == null || backgroundHandler == null
        ) {
            hopeScreenshotInProgress.set(false)
            hopeScreenshotResultCompleted.set(true)
            result.error(
                "SCREENSHOT_SURFACE_UNAVAILABLE",
                "FlutterImageView/ImageReader is not available after surface conversion.",
                null,
            )
            return
        }

        val captureTimeout = Runnable {
            if (hopeScreenshotInProgress.get() && !hopeScreenshotResultCompleted.get()) {
                imageReader.setOnImageAvailableListener(null, null)
                failHopeScreenshot(
                    result,
                    "SCREENSHOT_FRAME_TIMEOUT",
                    "No fresh Flutter frame/PixelCopy result arrived within the capture deadline.",
                )
            }
        }
        hopeScreenshotTimeoutRunnable = captureTimeout
        mainHandler.postDelayed(captureTimeout, HOPE_SCREENSHOT_FRAME_TIMEOUT_MS)

        if (forceFreshFrame) {
            // HOPE_SCREENSHOT_FORCE_FRESH_FRAME
            // Consume any queued frame from the previous page before listening;
            // only a subsequent Flutter frame may satisfy this capture request.
            flutterView.acquireLatestImageViewFrame()
        }

        imageReader.setOnImageAvailableListener(
            {
                mainHandler.post {
                    if (!hopeScreenshotInProgress.get()) {
                        return@post
                    }
                    tryAcquireHopeScreenshotFrame(
                        flutterView,
                        imageReader,
                        mainHandler,
                        backgroundHandler,
                        result,
                    )
                }
            },
            backgroundHandler,
        )

        if (forceFreshFrame) {
            // The old buffer was consumed above; request a new Flutter frame and
            // let the ImageReader callback capture that page rather than stale UI.
            requestHopeFrame()
            scheduleHopeFreshFrameRetry(
                flutterView, imageReader, mainHandler, backgroundHandler, result,
            )
        } else {
            // Register the listener first, then probe the current surface. A screen
            // can already have a rendered ImageReader frame when capture starts (as
            // happened on Home after Login); waiting only for a new callback blocks.
            // HOPE_SCREENSHOT_IMMEDIATE_FRAME_ATTEMPT
            mainHandler.post {
                if (!hopeScreenshotInProgress.get()) {
                    return@post
                }
                tryAcquireHopeScreenshotFrame(
                    flutterView,
                    imageReader,
                    mainHandler,
                    backgroundHandler,
                    result,
                )
            }
            scheduleHopeFreshFrameRetry(
                flutterView, imageReader, mainHandler, backgroundHandler, result,
            )
        }
    }

    private fun scheduleHopeFreshFrameRetry(
        flutterView: FlutterView,
        imageReader: ImageReader,
        mainHandler: Handler,
        backgroundHandler: Handler,
        result: MethodChannel.Result,
    ) {
        val retryRunnable = object : Runnable {
            override fun run() {
                if (!hopeScreenshotInProgress.get() || hopeScreenshotFrameCaptured.get()) {
                    return
                }
                tryAcquireHopeScreenshotFrame(
                    flutterView,
                    imageReader,
                    mainHandler,
                    backgroundHandler,
                    result,
                )
                if (hopeScreenshotInProgress.get() && !hopeScreenshotFrameCaptured.get()) {
                    mainHandler.postDelayed(this, HOPE_SCREENSHOT_FRAME_RETRY_INTERVAL_MS)
                }
            }
        }
        hopeScreenshotFrameRetryRunnable = retryRunnable
        mainHandler.postDelayed(retryRunnable, HOPE_SCREENSHOT_FRAME_RETRY_INTERVAL_MS)
    }

    private fun tryAcquireHopeScreenshotFrame(
        flutterView: FlutterView,
        imageReader: ImageReader,
        mainHandler: Handler,
        backgroundHandler: Handler,
        result: MethodChannel.Result,
    ) {
        if (!hopeScreenshotInProgress.get() || hopeScreenshotFrameCaptured.get()) {
            return
        }
        if (flutterView.acquireLatestImageViewFrame() &&
            hopeScreenshotFrameCaptured.compareAndSet(false, true)
        ) {
            imageReader.setOnImageAvailableListener(null, null)
            hopeScreenshotFrameRetryRunnable?.let { mainHandler.removeCallbacks(it) }
            hopeScreenshotFrameRetryRunnable = null
            scheduleHopePixelCopy(
                flutterView,
                mainHandler,
                backgroundHandler,
                result,
            )
            return
        }

        // No queued frame yet. Keep the listener armed and ask Flutter to commit
        // one; the listener will re-enter this method on availability.
        requestHopeFrame()
    }

    private fun requestHopeFrame() {
        MethodChannel(
            flutterEngine?.dartExecutor?.binaryMessenger
                ?: return,
            INTEGRATION_TEST_CHANNEL,
        ).invokeMethod("scheduleFrame", null)
    }

    private fun scheduleHopePixelCopy(
        flutterView: FlutterView,
        mainHandler: Handler,
        backgroundHandler: Handler,
        result: MethodChannel.Result,
    ) {
        waitForAndroidFrame(
            mainHandler,
            Runnable {
                waitForAndroidFrame(
                    mainHandler,
                    Runnable {
                        convertHopeViewToBitmap(
                            flutterView,
                            backgroundHandler,
                            result,
                        )
                    },
                )
            },
        )
    }

    private fun waitForAndroidFrame(handler: Handler, callback: Runnable) {
        handler.post {
            Choreographer.getInstance().postFrameCallback {
                callback.run()
            }
        }
    }

    private fun convertHopeViewToBitmap(
        flutterView: FlutterView,
        backgroundHandler: Handler,
        result: MethodChannel.Result,
    ) {
        val bitmap = try {
            Bitmap.createBitmap(
                flutterView.width,
                flutterView.height,
                Bitmap.Config.ARGB_8888,
            )
        } catch (error: Throwable) {
            failHopeScreenshot(
                result,
                "BITMAP_CREATE_FAILED",
                error.message ?: "Unable to create screenshot bitmap.",
            )
            return
        }

        val location = IntArray(2)
        flutterView.getLocationInWindow(location)
        val viewRect = Rect(
            location[0],
            location[1],
            location[0] + flutterView.width,
            location[1] + flutterView.height,
        )

        try {
            PixelCopy.request(
                window,
                viewRect,
                bitmap,
                { copyResult ->
                    if (copyResult == PixelCopy.SUCCESS) {
                        val output = ByteArrayOutputStream()
                        if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                            failHopeScreenshot(
                                result,
                                "PNG_ENCODE_FAILED",
                                "Bitmap compression returned false.",
                            )
                            return@request
                        }

                        hopeScreenshotMainHandler?.post {
                            completeHopeScreenshot(result, output.toByteArray())
                        }
                    } else {
                        failHopeScreenshot(
                            result,
                            "PIXEL_COPY_FAILED",
                            "PixelCopy returned result=$copyResult.",
                        )
                    }
                },
                backgroundHandler,
            )
        } catch (error: Throwable) {
            failHopeScreenshot(
                result,
                "PIXEL_COPY_REQUEST_FAILED",
                error.message ?: "PixelCopy request failed.",
            )
        }
    }

    private fun clearHopeScreenshotCaptureWatchdogs() {
        val mainHandler = hopeScreenshotMainHandler
        hopeScreenshotFrameRetryRunnable?.let { mainHandler?.removeCallbacks(it) }
        hopeScreenshotTimeoutRunnable?.let { mainHandler?.removeCallbacks(it) }
        hopeScreenshotFrameRetryRunnable = null
        hopeScreenshotTimeoutRunnable = null
    }

    private fun completeHopeScreenshot(
        result: MethodChannel.Result,
        bytes: ByteArray,
    ) {
        if (!hopeScreenshotResultCompleted.compareAndSet(false, true)) {
            return
        }
        hopeScreenshotInProgress.set(false)
        clearHopeScreenshotCaptureWatchdogs()
        result.success(bytes)
    }

    private fun failHopeScreenshot(
        result: MethodChannel.Result,
        code: String,
        message: String,
    ) {
        if (!hopeScreenshotResultCompleted.compareAndSet(false, true)) {
            return
        }
        hopeScreenshotInProgress.set(false)
        clearHopeScreenshotCaptureWatchdogs()
        hopeScreenshotMainHandler?.post {
            result.error(code, message, null)
        }
    }
}
