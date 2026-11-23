package com.example.keuangan_reza

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class ReZyQuickAddTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.let { tile ->
            tile.state = Tile.STATE_INACTIVE
            tile.label = "Catat Cepat"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = "ReZyLife"
            }
            tile.updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        val launch = Runnable { launchQuickAdd() }
        if (isLocked) {
            unlockAndRun(launch)
        } else {
            launch.run()
        }
    }

    private fun launchQuickAdd() {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_QUICK_ADD
            putExtra(EXTRA_QUICK_ADD, true)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                REQUEST_CODE_QUICK_ADD,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    companion object {
        const val ACTION_QUICK_ADD = "com.example.keuangan_reza.ACTION_QUICK_ADD"
        const val EXTRA_QUICK_ADD = "extra_quick_add"
        private const val REQUEST_CODE_QUICK_ADD = 1001
    }
}
