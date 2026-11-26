package com.example.keuangan_reza

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var notifChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingQuickAdd = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighRefreshRate()
        handleQuickAddIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleQuickAddIntent(intent)
    }

    private fun handleQuickAddIntent(incoming: Intent?) {
        if (incoming == null) return
        val isQuickAdd =
            incoming.action == ReZyQuickAddTileService.ACTION_QUICK_ADD ||
                incoming.getBooleanExtra(ReZyQuickAddTileService.EXTRA_QUICK_ADD, false)
        if (!isQuickAdd) return

        // Clear flag so activity recreation or recents restore does not re-trigger.
        incoming.removeExtra(ReZyQuickAddTileService.EXTRA_QUICK_ADD)
        if (incoming.action == ReZyQuickAddTileService.ACTION_QUICK_ADD) {
            incoming.action = Intent.ACTION_MAIN
        }

        val channel = notifChannel
        if (channel != null) {
            mainHandler.post {
                channel.invokeMethod("onQuickAddRequested", null)
            }
        } else {
            pendingQuickAdd = true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        notifChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingQuickAdd" -> {
                    val value = pendingQuickAdd
                    pendingQuickAdd = false
                    result.success(value)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        notifChannel?.setMethodCallHandler(null)
        notifChannel = null
        super.onDestroy()
    }

    private fun requestHighRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        } ?: return

        val bestMode = currentDisplay.supportedModes.maxByOrNull { it.refreshRate } ?: return
        val params = window.attributes
        params.preferredDisplayModeId = bestMode.modeId
        params.preferredRefreshRate = bestMode.refreshRate
        window.attributes = params
    }

    companion object {
        private const val CHANNEL_NAME = "rezylife/notifications"
    }
}
