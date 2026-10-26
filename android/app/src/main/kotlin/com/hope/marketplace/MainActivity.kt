package com.hope.marketplace

import android.graphics.Bitmap
import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Rect
import android.media.ImageReader
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import android.view.Choreographer
import android.view.PixelCopy
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterImageView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val HOPE_SCREENSHOT_CHANNEL = "hope.runtime/screenshot"
        private const val HOPE_CHAT_VOICE_CHANNEL = "hope.chat/voice"
        private const val CHAT_VOICE_PERMISSION_REQUEST = 7406
        private const val INTEGRATION_TEST_CHANNEL = "plugins.flutter.io/integration_test"
        private const val HOPE_SCREENSHOT_FRAME_TIMEOUT_MS = 15_000L
        private const val HOPE_SCREENSHOT_FRAME_RETRY_INTERVAL_MS = 250L
        private const val HOPE_SCREENSHOT_LOG_TAG = "HopeRuntimeScreenshot"
    }

    private var hopeScreenshotThread: HandlerThread? = null
    private var hopeScreenshotBackgroundHandler: Handler? = null
    private var hopeScreenshotMainHandler: Handler? = null
    private var chatVoiceRecorder: MediaRecorder? = null
    private var chatVoicePlayer: MediaPlayer? = null
    private var chatVoiceMethodChannel: MethodChannel? = null
    private var chatVoiceOutputPath: String? = null
    private var pendingChatVoiceStartResult: MethodChannel.Result? = null
    private val hopeScreenshotInProgress = AtomicBoolean(false)
    private val hopeScreenshotFrameCaptured = AtomicBoolean(false)
    private val hopeScreenshotResultCompleted = AtomicBoolean(false)
    @Volatile private var hopeScreenshotCapturePhase = "idle"
    @Volatile private var hopeScreenshotRequestName = "unlabelled"
    @Volatile private var hopeScreenshotFreshFramesRemaining = 0
    @Volatile private var hopeScreenshotFrameRequestCount = 0
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

        // Product voice controls are available in release; screenshot plumbing remains debug-only.
        val chatVoiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HOPE_CHAT_VOICE_CHANNEL)
        chatVoiceMethodChannel = chatVoiceChannel
        chatVoiceChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> startChatVoiceRecording(result)
                    "cancelPendingRecording" -> cancelPendingChatVoiceRecording(result)
                    "stopRecording" -> stopChatVoiceRecording(result)
                    "playFile" -> playChatVoiceFile(call.argument<String>("path"), result)
                    "stopPlayback" -> stopChatVoicePlayback(result)
                    else -> result.notImplemented()
                }
            }

        if (!BuildConfig.DEBUG) return

        hopeScreenshotMainHandler = Handler(Looper.getMainLooper())
        hopeScreenshotThread = HandlerThread("hope-runtime-screenshot").also { it.start() }
        hopeScreenshotBackgroundHandler = Handler(hopeScreenshotThread!!.looper)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HOPE_SCREENSHOT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureScreenshot" -> {
                    val forceFreshFrame = call.argument<Boolean>("forceFreshFrame") ?: false
                    val freshFramesRequired = call.argument<Int>("freshFramesRequired")
                        ?: if (forceFreshFrame) 2 else 0
                    captureHopeScreenshot(
                        result,
                        call.argument<String>("screenshotName") ?: "unlabelled",
                        forceFreshFrame,
                        freshFramesRequired,
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try { chatVoiceRecorder?.stop() } catch (_: Throwable) {}
        try { chatVoiceRecorder?.release() } catch (_: Throwable) {}
        chatVoiceRecorder = null
        try { chatVoicePlayer?.stop() } catch (_: Throwable) {}
        try { chatVoicePlayer?.release() } catch (_: Throwable) {}
        chatVoicePlayer = null
        chatVoiceMethodChannel = null
        pendingChatVoiceStartResult = null
        clearHopeScreenshotCaptureWatchdogs()
        hopeScreenshotBackgroundHandler?.post {
            hopeScreenshotThread?.quitSafely()
        }
        hopeScreenshotThread = null
        hopeScreenshotBackgroundHandler = null
        hopeScreenshotMainHandler = null
        super.onDestroy()
    }


    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CHAT_VOICE_PERMISSION_REQUEST) return
        val result = pendingChatVoiceStartResult ?: return
        pendingChatVoiceStartResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startChatVoiceRecording(result)
        } else {
            result.error("MICROPHONE_PERMISSION_DENIED", "Microphone permission was denied.", null)
        }
    }

    private fun cancelPendingChatVoiceRecording(result: MethodChannel.Result) {
        // Clear the callback before completing it: a late permission result must
        // see no pending request and therefore must not start microphone capture.
        val pending = pendingChatVoiceStartResult
        pendingChatVoiceStartResult = null
        pending?.error("VOICE_RECORDING_CANCELLED", "Voice recording start was cancelled.", null)
        result.success(null)
    }

    private fun startChatVoiceRecording(result: MethodChannel.Result) {
        if (chatVoiceRecorder != null) {
            result.error("VOICE_RECORDING_ACTIVE", "A voice message is already being recorded.", null)
            return
        }
        if (pendingChatVoiceStartResult != null) {
            result.error("VOICE_PERMISSION_REQUEST_PENDING", "A microphone permission request is already pending.", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingChatVoiceStartResult = result
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), CHAT_VOICE_PERMISSION_REQUEST)
            return
        }
        val output = File(cacheDir, "hope-chat-" + System.currentTimeMillis() + ".m4a")
        var recorder: MediaRecorder? = null
        try {
            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(this) else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioEncodingBitRate(96000)
            recorder.setAudioSamplingRate(44100)
            recorder.setOutputFile(output.absolutePath)
            recorder.prepare()
            recorder.start()
            chatVoiceOutputPath = output.absolutePath
            chatVoiceRecorder = recorder
            result.success(output.absolutePath)
        } catch (error: Throwable) {
            try { recorder?.release() } catch (_: Throwable) {}
            try { output.delete() } catch (_: Throwable) {}
            chatVoiceOutputPath = null
            chatVoiceRecorder = null
            result.error("VOICE_RECORDING_FAILED", error.message ?: "Could not start recording.", null)
        }
    }

    private fun stopChatVoiceRecording(result: MethodChannel.Result) {
        val recorder = chatVoiceRecorder
        val outputPath = chatVoiceOutputPath
        if (recorder == null || outputPath.isNullOrEmpty()) {
            result.error("VOICE_RECORDING_NOT_ACTIVE", "No voice message is being recorded.", null)
            return
        }
        try {
            recorder.stop()
            recorder.release()
            chatVoiceRecorder = null
            chatVoiceOutputPath = null
            val output = File(outputPath)
            if (!output.exists() || output.length() <= 0L) {
                output.delete()
                result.error("VOICE_RECORDING_EMPTY", "The voice message is empty.", null)
            } else {
                result.success(output.absolutePath)
            }
        } catch (error: Throwable) {
            try { recorder.release() } catch (_: Throwable) {}
            chatVoiceRecorder = null
            chatVoiceOutputPath = null
            try { File(outputPath).delete() } catch (_: Throwable) {}
            result.error("VOICE_RECORDING_FAILED", error.message ?: "Could not finish recording.", null)
        }
    }

    private fun playChatVoiceFile(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("VOICE_PATH_REQUIRED", "A voice message path is required.", null)
            return
        }
        try {
            chatVoicePlayer?.let {
                try { it.stop() } catch (_: Throwable) {}
                it.release()
            }
            chatVoicePlayer = MediaPlayer().apply {
                setDataSource(path)
                setOnCompletionListener { player ->
                    try { player.release() } catch (_: Throwable) {}
                    if (chatVoicePlayer === player) {
                        chatVoicePlayer = null
                        chatVoiceMethodChannel?.invokeMethod("playbackCompleted", null)
                    }
                }
                prepare()
                start()
            }
            result.success(true)
        } catch (error: Throwable) {
            try { chatVoicePlayer?.release() } catch (_: Throwable) {}
            chatVoicePlayer = null
            result.error("VOICE_PLAYBACK_FAILED", error.message ?: "Could not play the voice message.", null)
        }
    }

    private fun stopChatVoicePlayback(result: MethodChannel.Result) {
        try { chatVoicePlayer?.stop() } catch (_: Throwable) {}
        try { chatVoicePlayer?.release() } catch (_: Throwable) {}
        chatVoicePlayer = null
        result.success(true)
    }

    private fun captureHopeScreenshot(
        result: MethodChannel.Result,
        screenshotName: String = "unlabelled",
        forceFreshFrame: Boolean = false,
        freshFramesRequired: Int = 0,
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
        hopeScreenshotCapturePhase = "surface-acquisition"
        hopeScreenshotRequestName = screenshotName
        hopeScreenshotFreshFramesRemaining =
            if (forceFreshFrame) freshFramesRequired.coerceIn(1, 2) else 0
        hopeScreenshotFrameRequestCount = 0
        Log.i(
            HOPE_SCREENSHOT_LOG_TAG,
            "HOPE_SCREENSHOT_CAPTURE_REQUEST:$screenshotName:forceFreshFrame=$forceFreshFrame:freshFramesRequired=$freshFramesRequired",
        )

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
                val phase = hopeScreenshotCapturePhase
                Log.e(
                    HOPE_SCREENSHOT_LOG_TAG,
                    "HOPE_SCREENSHOT_TIMEOUT:phase=$phase:forceFreshFrame=$forceFreshFrame",
                )
                imageReader.setOnImageAvailableListener(null, null)
                failHopeScreenshot(
                    result,
                    "SCREENSHOT_FRAME_TIMEOUT",
                    "Timed out during phase=$phase (forceFreshFrame=$forceFreshFrame); "
                        + "no fresh Flutter frame/PixelCopy result arrived.",
                )
            }
        }
        hopeScreenshotTimeoutRunnable = captureTimeout
        mainHandler.postDelayed(captureTimeout, HOPE_SCREENSHOT_FRAME_TIMEOUT_MS)

        // Register the listener before checking or draining reader state so callbacks
        // from racing frames are not lost. Normal captures retain the committed-frame
        // fast path; strict authentication captures drain that candidate and wait for
        // the requested number of later ImageReader deliveries.
        imageReader.setOnImageAvailableListener(
            {
                mainHandler.post {
                    if (!hopeScreenshotInProgress.get()) {
                        return@post
                    }
                    Log.i(
                        HOPE_SCREENSHOT_LOG_TAG,
                        "HOPE_SCREENSHOT_IMAGE_AVAILABLE:$hopeScreenshotRequestName:phase=$hopeScreenshotCapturePhase:remaining=$hopeScreenshotFreshFramesRemaining",
                    )
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
            // HOPE_SCREENSHOT_FORCE_FRESH_FRAME
            // The frame already queued at this auth marker boundary is untrusted.
            // Drain it, then require the configured number of later ImageReader deliveries before PixelCopy.
            val queuedFrameDrained = flutterView.acquireLatestImageViewFrame()
            Log.i(
                HOPE_SCREENSHOT_LOG_TAG,
                "HOPE_SCREENSHOT_STALE_FRAME_DRAINED:$screenshotName:available=$queuedFrameDrained",
            )
            hopeScreenshotCapturePhase = "waiting-for-new-flutter-frame"
            requestHopeFrame()
            scheduleHopeFreshFrameRetry(
                flutterView, imageReader, mainHandler, backgroundHandler, result,
            )
        } else {
            // HOPE_SCREENSHOT_IMMEDIATE_FRAME_ATTEMPT
            hopeScreenshotCapturePhase = "checking-initial-frame"
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
        val frameAvailable = flutterView.acquireLatestImageViewFrame()
        if (frameAvailable) {
            if (hopeScreenshotFreshFramesRemaining > 1) {
                hopeScreenshotFreshFramesRemaining -= 1
                Log.i(
                    HOPE_SCREENSHOT_LOG_TAG,
                    "HOPE_SCREENSHOT_STALE_FRAME_REJECTED:$hopeScreenshotRequestName:remaining=$hopeScreenshotFreshFramesRemaining",
                )
                requestHopeFrame()
                return
            }
            if (hopeScreenshotFrameCaptured.compareAndSet(false, true)) {
                hopeScreenshotFreshFramesRemaining = 0
                hopeScreenshotCapturePhase = "waiting-for-pixelcopy"
                Log.i(
                    HOPE_SCREENSHOT_LOG_TAG,
                    "HOPE_SCREENSHOT_FRAME_ACQUIRED:$hopeScreenshotRequestName:source=image-reader-callback",
                )
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
        }

        // No eligible frame yet. Keep the listener armed and request another frame.
        requestHopeFrame()
    }

    private fun requestHopeFrame() {
        if (hopeScreenshotInProgress.get() && !hopeScreenshotFrameCaptured.get()) {
            hopeScreenshotCapturePhase = "waiting-for-new-flutter-frame"
        }
        hopeScreenshotFrameRequestCount += 1
        Log.i(
            HOPE_SCREENSHOT_LOG_TAG,
            "HOPE_SCREENSHOT_FRAME_REQUEST_SENT:$hopeScreenshotRequestName:count=$hopeScreenshotFrameRequestCount:phase=$hopeScreenshotCapturePhase",
        )
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
        hopeScreenshotCapturePhase = "waiting-for-android-presentation-frames"
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
        hopeScreenshotCapturePhase = "pixelcopy-pending"
        Log.i(
            HOPE_SCREENSHOT_LOG_TAG,
            "HOPE_SCREENSHOT_PIXELCOPY_START:${flutterView.width}x${flutterView.height}:marker=$hopeScreenshotRequestName",
        )
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
                    Log.i(HOPE_SCREENSHOT_LOG_TAG, "HOPE_SCREENSHOT_PIXELCOPY_CALLBACK:$copyResult")
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
        hopeScreenshotCapturePhase = "completed"
        clearHopeScreenshotCaptureWatchdogs()
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { byte ->
            (byte.toInt() and 0xff).toString(16).padStart(2, '0')
        }
        Log.i(
            HOPE_SCREENSHOT_LOG_TAG,
            "HOPE_SCREENSHOT_CAPTURE_COMPLETE:$hopeScreenshotRequestName:bytes=${bytes.size}:sha256=$digest",
        )
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
        hopeScreenshotCapturePhase = "failed:$code"
        clearHopeScreenshotCaptureWatchdogs()
        Log.e(HOPE_SCREENSHOT_LOG_TAG, "HOPE_SCREENSHOT_CAPTURE_FAILED:$code:$message")
        hopeScreenshotMainHandler?.post {
            result.error(code, message, null)
        }
    }
}
