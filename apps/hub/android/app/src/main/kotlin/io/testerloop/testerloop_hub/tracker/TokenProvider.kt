package io.testerloop.testerloop_hub.tracker

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Binder

/**
 * Exposes opaque tracking JWTs exclusively to the calling Android package.
 * Verified via Binder callingPackage / getCallingPackage() so one app can never
 * read another app's enrollment token.
 */
class TokenProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor? {
        val ctx = context ?: return null
        val caller = resolveCallingPackage(ctx) ?: return null
        val token = TokenStorage.readToken(ctx, caller)

        val cursor = MatrixCursor(arrayOf("token"))
        if (!token.isNullOrBlank()) {
            cursor.addRow(arrayOf(token))
        }
        return cursor
    }

    private fun resolveCallingPackage(ctx: Context): String? {
        val cp = callingPackage
        if (!cp.isNullOrBlank()) return cp
        val uid = Binder.getCallingUid()
        return ctx.packageManager.getPackagesForUid(uid)?.firstOrNull()
    }

    override fun getType(uri: Uri): String = "vnd.android.cursor.item/vnd.io.testerloop.token"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
}

internal object TokenStorage {
    private const val PREFS = "testerloop_hub_tokens"

    fun saveToken(context: Context, packageName: String, token: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(packageName, token)
            .apply()
    }

    fun readToken(context: Context, packageName: String): String? {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(packageName, null)
    }
}
