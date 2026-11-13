package io.testerloop.sdk.internal

import android.content.Context
import androidx.startup.Initializer
import io.testerloop.sdk.TesterLoop

internal class TesterLoopInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        TesterLoop.init(context)
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
