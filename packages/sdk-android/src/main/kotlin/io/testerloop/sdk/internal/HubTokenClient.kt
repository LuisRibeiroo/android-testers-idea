package io.testerloop.sdk.internal

import android.content.Context
import android.net.Uri

internal object HubTokenClient {
    private val TOKEN_URI = Uri.parse("content://io.testerloop.hub.token/token")

    fun fetchToken(context: Context): String? {
        return runCatching {
            context.contentResolver.query(TOKEN_URI, arrayOf("token"), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex("token")
                    if (idx >= 0) cursor.getString(idx) else null
                } else {
                    null
                }
            }
        }.getOrNull()
    }
}
