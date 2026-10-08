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
    }

    private var hopeScreenshotThread: HandlerThread? = null
    private var hopeScreenshotBackgroundHandler: Handler? = null
    private var hopeScreenshotMainHandler: Handler? = null
    private val hopeScreenshotInProgress = AtomicBoolean(false)

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
                "captureScreenshot" -> captureHopeScreenshot(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        hopeScreenshotBackgroundHandler?.post {
            hopeScreenshotThread?.quitSafely()
        }
        hopeScreenshotThread = null
        hopeScreenshotBackgroundHandler = null
        hopeScreenshotMainHandler = null
        super.onDestroy()
    }

    private fun captureHopeScreenshot(result: MethodChannel.Result) {
        if (!hopeScreenshotInProgress.compareAndSet(false, true)) {
            result.error(
                "CAPTURE_IN_PROGRESS",
                "Another HOPE runtime screenshot is already being captured.",
                null,
            )
            return
        }

        val flutterView = findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)
        val imageView: FlutterImageView? = flutterView?.getCurrentImageSurface()
        val imageReader = imageView?.getImageReader()
        val mainHandler = hopeScreenshotMainHandler
        val backgroundHandler = hopeScreenshotBackgroundHandler

        if (flutterView == null || imageView == null || imageReader == null ||
            mainHandler == null || backgroundHandler == null
        ) {
            hopeScreenshotInProgress.set(false)
            result.error(
                "SCREENSHOT_SURFACE_UNAVAILABLE",
                "FlutterImageView/ImageReader is not available after surface conversion.",
                null,
            )
            return
        }

        imageReader.setOnImageAvailableListener(
            {
                mainHandler.post {
                    if (!hopeScreenshotInProgress.get()) {
                        return@post
                    }

                    imageReader.setOnImageAvailableListener(null, null)
                    if (!flutterView.acquireLatestImageViewFrame()) {
                        // A concurrent frame transition may have consumed this image.
                        // Re-arm the listener before scheduling the next frame; the
                        // acquisition itself only runs on the UI thread once an image
                        // is already reported by ImageReader.
                        imageReader.setOnImageAvailableListener(
                            {
                                mainHandler.post {
                                    if (!hopeScreenshotInProgress.get()) {
                                        return@post
                                    }
                                    imageReader.setOnImageAvailableListener(null, null)
                                    if (flutterView.acquireLatestImageViewFrame()) {
                                        scheduleHopePixelCopy(
                                            flutterView,
                                            mainHandler,
                                            backgroundHandler,
                                            result,
                                        )
                                    } else {
                                        failHopeScreenshot(
                                            result,
                                            "IMAGE_FRAME_UNAVAILABLE",
                                            "ImageReader reported a frame but FlutterImageView did not acquire it.",
                                        )
                                    }
                                }
                            },
                            backgroundHandler,
                        )
                        requestHopeFrame()
                        return@post
                    }

                    scheduleHopePixelCopy(
                        flutterView,
                        mainHandler,
                        backgroundHandler,
                        result,
                    )
                }
            },
            backgroundHandler,
        )

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

    private fun completeHopeScreenshot(
        result: MethodChannel.Result,
        bytes: ByteArray,
    ) {
        hopeScreenshotInProgress.set(false)
        result.success(bytes)
    }

    private fun failHopeScreenshot(
        result: MethodChannel.Result,
        code: String,
        message: String,
    ) {
        hopeScreenshotInProgress.set(false)
        hopeScreenshotMainHandler?.post {
            result.error(code, message, null)
        }
    }
}
