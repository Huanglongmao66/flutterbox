package com.github.tvbox.tvbox

import android.content.Context
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "tvbox/player/exo"
    private var exoPlayer: ExoPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val url = call.argument<String>("url") ?: ""
                val autoPlay = call.argument<Boolean>("autoPlay") ?: true
                open(url, autoPlay)
                result.success(null)
            }
            "play" -> { exoPlayer?.play(); result.success(null) }
            "pause" -> { exoPlayer?.pause(); result.success(null) }
            "seek" -> {
                val ms = (call.argument<Number>("ms") ?: 0).toLong()
                exoPlayer?.seekTo(ms)
                result.success(null)
            }
            "setSpeed" -> {
                val speed = (call.argument<Number>("speed") ?: 1.0).toFloat()
                exoPlayer?.playbackParameters = PlaybackParameters(speed)
                result.success(null)
            }
            "setVolume" -> {
                val v = (call.argument<Number>("volume") ?: 1.0).toFloat()
                exoPlayer?.volume = v.coerceIn(0f, 1f)
                result.success(null)
            }
            "dispose" -> {
                exoPlayer?.release()
                exoPlayer = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun open(url: String, autoPlay: Boolean) {
        if (url.isEmpty()) return
        exoPlayer?.release()
        val player = ExoPlayer.Builder(this).build()
        val mediaItem = MediaItem.fromUri(Uri.parse(url))
        player.setMediaItem(mediaItem)
        player.prepare()
        player.playWhenReady = autoPlay
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                send(if (isPlaying) "onPlaying" else "onPaused", null)
            }
            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                send("onPosition", player.currentPosition)
            }
            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_READY -> send("onDuration", player.duration)
                    Player.STATE_BUFFERING -> send("onBuffering", player.bufferedPosition)
                    Player.STATE_ENDED -> send("onCompleted", null)
                }
            }
        })
        exoPlayer = player
    }

    private fun send(method: String, arg: Any?) {
        // 通过主引擎的 dartExecutor 发送事件
        runOnUiThread {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { m ->
                MethodChannel(m, channelName).invokeMethod(method, arg)
            }
        }
    }

    override fun onDestroy() {
        exoPlayer?.release()
        exoPlayer = null
        super.onDestroy()
    }
}
