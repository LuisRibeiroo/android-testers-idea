package io.testerloop.testerloop_hub.tracker

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class HubNativePlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listTrackedApps" -> {
                result.success(TrackedAppsScanner.listTrackedPackages(context))
            }
            "isPackageInstalled" -> {
                val pkg = call.argument<String>("packageName") ?: ""
                result.success(TrackedAppsScanner.isPackageInstalled(context, pkg))
            }
            "saveTrackingToken" -> {
                val pkg = call.argument<String>("packageName") ?: ""
                val token = call.argument<String>("token") ?: ""
                if (pkg.isNotBlank() && token.isNotBlank()) {
                    TokenStorage.saveToken(context, pkg, token)
                }
                result.success(null)
            }
            "launchWithToken" -> {
                val pkg = call.argument<String>("packageName") ?: ""
                val token = call.argument<String>("token") ?: ""
                result.success(TrackedAppsScanner.launchWithToken(context, pkg, token))
            }
            "getDeviceIdentity" -> {
                val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"
                val hash = MessageDigest.getInstance("SHA-256")
                    .digest(androidId.toByteArray())
                    .joinToString("") { "%02x".format(it) }
                result.success(
                    mapOf(
                        "androidIdHash" to hash,
                        "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                        "sdkInt" to Build.VERSION.SDK_INT
                    )
                )
            }
            "openExternalUrl" -> {
                val url = call.argument<String>("url") ?: ""
                val opened = runCatching {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    true
                }.getOrDefault(false)
                result.success(opened)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "io.testerloop.hub/native"
    }
}
