package com.sai.knot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Kiosk boot auto-launch (TASKS.md 6.38): when the user enables "Launch on
 * boot" in Settings, reopen the app after the device restarts so a
 * wall-mounted tablet comes back to the wall display by itself.
 *
 * Reads the shared_preferences flag Flutter writes (`flutter.` prefix in the
 * FlutterSharedPreferences file). Note: on Android 10+ launching an activity
 * from the background additionally requires the "Display over other apps"
 * permission, which dedicated kiosk tablets should grant to Knot.
 */
class BootLaunchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        if (!prefs.getBoolean("flutter.kioskBootLaunch", false)) return
        val launch =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(launch)
    }
}
