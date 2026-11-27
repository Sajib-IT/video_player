package com.cinevault.player.video_player

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {
    private val pipMethodChannel = "com.cinevault.player/pip"
    private val pipEventChannel = "com.cinevault.player/pip_events"
    private var pipEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, pipEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    pipEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    pipEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipMethodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> {
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    }
                    "enterPipMode" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val width = call.argument<Int>("width") ?: 16
                        val height = call.argument<Int>("height") ?: 9
                        val ratio = clampPipRatio(width, height)
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(ratio)
                            .build()
                        val entered = enterPictureInPictureMode(params)
                        result.success(entered)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipEventSink?.success(isInPictureInPictureMode)
    }

    private fun clampPipRatio(rawWidth: Int, rawHeight: Int): Rational {
        val w = if (rawWidth > 0) rawWidth else 16
        val h = if (rawHeight > 0) rawHeight else 9
        val ratio = w.toDouble() / h.toDouble()
        return when {
            ratio < 0.42 -> Rational(42, 100)
            ratio > 2.39 -> Rational(239, 100)
            else -> Rational(w, h)
        }
    }
}
