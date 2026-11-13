package io.testerloop.sdk.internal

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.testerloop.sdk.TesterLoop

internal class EntryActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        runCatching {
            val token = intent?.getStringExtra(EXTRA_TOKEN)
            if (!token.isNullOrBlank()) {
                TokenStore(applicationContext).saveToken(token)
            }
            TesterLoop.init(applicationContext)

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            if (launchIntent != null) {
                startActivity(launchIntent)
            }
        }
        finish()
    }

    companion object {
        const val EXTRA_TOKEN = "io.testerloop.extra.TOKEN"
    }
}
