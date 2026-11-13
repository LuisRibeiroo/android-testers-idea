package io.testerloop.sdk.internal

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest

internal object AppInfo {
    private const val META_APP_KEY = "io.testerloop.APP_KEY"

    fun readAppKey(context: Context): String? {
        return runCatching {
            val ai = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getApplicationInfo(
                    context.packageName,
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            }
            ai.metaData?.getString(META_APP_KEY)?.trim()
        }.getOrNull()
    }

    fun isDebuggable(context: Context): Boolean {
        return (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    fun getInstallerPackage(context: Context): String? {
        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getInstallerPackageName(context.packageName)
            }
        }.getOrNull()
    }

    fun getVersionCode(context: Context): Long {
        return runCatching {
            val pkg = getPackageInfo(context, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkg.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                pkg.versionCode.toLong()
            }
        }.getOrDefault(0L)
    }

    fun getSigningCertSha256(context: Context): String {
        return runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val pkg = getPackageInfo(context, PackageManager.GET_SIGNING_CERTIFICATES)
                val info = pkg.signingInfo ?: return ""
                val signers = if (info.hasMultipleSigners()) info.apkContentsSigners else info.signingCertificateHistory
                val certBytes = signers?.firstOrNull()?.toByteArray() ?: return ""
                sha256Hex(certBytes)
            } else {
                @Suppress("DEPRECATION")
                val pkg = getPackageInfo(context, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                val certBytes = pkg.signatures?.firstOrNull()?.toByteArray() ?: return ""
                sha256Hex(certBytes)
            }
        }.getOrDefault("")
    }

    private fun getPackageInfo(context: Context, flags: Int): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(flags.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, flags)
        }
    }

    private fun sha256Hex(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString(":") { "%02X".format(it) }
    }
}
