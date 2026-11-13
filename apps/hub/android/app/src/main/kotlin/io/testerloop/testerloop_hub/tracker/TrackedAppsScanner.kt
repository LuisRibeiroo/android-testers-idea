package io.testerloop.testerloop_hub.tracker

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

internal object TrackedAppsScanner {
    const val ACTION_OPEN = "io.testerloop.action.OPEN"
    const val EXTRA_TOKEN = "io.testerloop.extra.TOKEN"

    fun listTrackedPackages(context: Context): List<String> {
        val intent = Intent(ACTION_OPEN)
        val matches = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0L)
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.queryIntentActivities(intent, 0)
        }
        return matches.mapNotNull { it.activityInfo?.packageName }.distinct()
    }

    fun isPackageInstalled(context: Context, packageName: String): Boolean {
        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(packageName, 0)
            }
            true
        }.getOrDefault(false)
    }

    fun launchWithToken(context: Context, packageName: String, token: String): Boolean {
        TokenStorage.saveToken(context, packageName, token)
        val sdkIntent = Intent(ACTION_OPEN).apply {
            setPackage(packageName)
            putExtra(EXTRA_TOKEN, token)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val canHandleSdkIntent = sdkIntent.resolveActivity(context.packageManager) != null
        if (canHandleSdkIntent) {
            context.startActivity(sdkIntent)
            return true
        }
        val fallback = context.packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        } ?: return false
        context.startActivity(fallback)
        return true
    }
}
