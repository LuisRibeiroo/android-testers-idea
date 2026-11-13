package io.testerloop.sdk.internal

import android.content.Context
import java.util.UUID

internal class TokenStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getToken(): String? = prefs.getString(KEY_TOKEN, null)

    fun saveToken(token: String) {
        prefs.edit().putString(KEY_TOKEN, token).apply()
    }

    fun getOrCreateInstallId(): String {
        val existing = prefs.getString(KEY_INSTALL_ID, null)
        if (!existing.isNullOrBlank()) return existing
        val created = UUID.randomUUID().toString()
        prefs.edit().putString(KEY_INSTALL_ID, created).apply()
        return created
    }

    fun isEnabled(): Boolean = prefs.getBoolean(KEY_ENABLED, true)

    fun setEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun getFlushIntervalSec(): Int = prefs.getInt(KEY_FLUSH_INTERVAL_SEC, Config.DEFAULT_FLUSH_SEC)

    fun setFlushIntervalSec(seconds: Int) {
        prefs.edit().putInt(KEY_FLUSH_INTERVAL_SEC, seconds.coerceIn(10, 300)).apply()
    }

    companion object {
        private const val PREFS_NAME = "io.testerloop.sdk.prefs"
        private const val KEY_TOKEN = "tracking_token"
        private const val KEY_INSTALL_ID = "install_id"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_FLUSH_INTERVAL_SEC = "flush_interval_sec"
    }
}
