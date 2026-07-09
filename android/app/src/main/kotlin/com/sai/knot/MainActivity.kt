package com.sai.knot

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var oauthChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        oauthChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sai.knot/oauth_callback"
        )
        forwardOAuthRedirect(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        forwardOAuthRedirect(intent)
    }

    private fun forwardOAuthRedirect(intent: Intent?) {
        val url = intent?.dataString ?: return
        if (url.startsWith("knot://oauth")) {
            oauthChannel?.invokeMethod("redirect", url)
        }
    }
}
