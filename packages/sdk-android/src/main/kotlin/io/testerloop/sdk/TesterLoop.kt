package io.testerloop.sdk

import android.content.Context
import android.util.Log
import io.testerloop.sdk.internal.ApiClient
import io.testerloop.sdk.internal.AppInfo
import io.testerloop.sdk.internal.Config
import io.testerloop.sdk.internal.EventQueue
import io.testerloop.sdk.internal.HubTokenClient
import io.testerloop.sdk.internal.SessionTracker
import io.testerloop.sdk.internal.TokenStore
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

object TesterLoop {
    private const val TAG = "TesterLoop"
    private val initialized = AtomicBoolean(false)
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "testerloop-sdk").apply { isDaemon = true }
    }

    @Volatile
    private var wrapperName: String? = null

    internal fun setWrapper(wrapper: String?) {
        wrapperName = wrapper
    }

    @JvmStatic
    @JvmOverloads
    fun init(context: Context, appKey: String? = null) {
        runCatching {
            val appCtx = context.applicationContext
            if (!initialized.compareAndSet(false, true)) {
                return
            }
            val store = TokenStore(appCtx)
            val resolvedKey = appKey ?: AppInfo.readAppKey(appCtx)
            if (resolvedKey.isNullOrBlank()) {
                if (AppInfo.isDebuggable(appCtx)) {
                    Log.w(TAG, "Missing io.testerloop.APP_KEY meta-data; SDK disabled.")
                }
                return
            }

            val queue = EventQueue(appCtx)
            val api = ApiClient(Config.DEFAULT_BASE_URL)
            val tracker = SessionTracker(
                context = appCtx,
                appKey = resolvedKey,
                wrapper = wrapperName,
                store = store,
                queue = queue,
                api = api,
                executor = executor
            )
            tracker.attach()

            executor.execute {
                runCatching {
                    if (store.getToken().isNullOrBlank()) {
                        HubTokenClient.fetchToken(appCtx)?.let { store.saveToken(it) }
                    }
                    tracker.performHandshakeIfNeeded()
                }
            }

            if (AppInfo.isDebuggable(appCtx)) {
                Log.i(TAG, "initialized (appKey=${resolvedKey.take(12)}..., sdk=${Config.SDK_VERSION})")
                Log.i(TAG, "${status(appCtx).name} (open this app from the TesterLoop Hub to validate)")
            }
        }
    }

    @JvmStatic
    fun status(context: Context): TesterLoopStatus {
        return runCatching {
            val store = TokenStore(context.applicationContext)
            if (!store.isEnabled()) {
                TesterLoopStatus.DISABLED
            } else if (store.getToken().isNullOrBlank()) {
                TesterLoopStatus.NOT_ENROLLED
            } else {
                TesterLoopStatus.TRACKING
            }
        }.getOrDefault(TesterLoopStatus.DISABLED)
    }

    @JvmStatic
    fun setEnabled(context: Context, enabled: Boolean) {
        runCatching {
            TokenStore(context.applicationContext).setEnabled(enabled)
        }
    }
}
