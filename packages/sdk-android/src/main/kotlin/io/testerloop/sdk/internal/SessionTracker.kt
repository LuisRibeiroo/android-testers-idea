package io.testerloop.sdk.internal

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.Executor

internal class SessionTracker(
    private val context: Context,
    private val appKey: String,
    private val wrapper: String?,
    private val store: TokenStore,
    private val queue: EventQueue,
    private val api: ApiClient,
    private val executor: Executor
) : DefaultLifecycleObserver {

    private var sessionStartMs: Long = 0L

    fun attach() {
        Handler(Looper.getMainLooper()).post {
            runCatching {
                ProcessLifecycleOwner.get().lifecycle.addObserver(this)
            }
        }
    }

    override fun onStart(owner: LifecycleOwner) {
        sessionStartMs = System.currentTimeMillis()
        val ping = JSONObject()
            .put("type", "ping")
            .put("id", UUID.randomUUID().toString())
            .put("clientTs", sessionStartMs)
        queue.enqueue(ping)
        flushAsync()
    }

    override fun onStop(owner: LifecycleOwner) {
        val now = System.currentTimeMillis()
        if (sessionStartMs > 0L && now >= sessionStartMs) {
            val session = JSONObject()
                .put("type", "session")
                .put("id", UUID.randomUUID().toString())
                .put("startTs", sessionStartMs)
                .put("foregroundMs", now - sessionStartMs)
            queue.enqueue(session)
        }
        sessionStartMs = 0L
        flushAsync()
    }

    fun performHandshakeIfNeeded() {
        if (!store.isEnabled()) return
        val token = store.getToken() ?: HubTokenClient.fetchToken(context)?.also { store.saveToken(it) }
        val payload = JSONObject()
            .put("appKey", appKey)
            .put("packageName", context.packageName)
            .put("versionCode", AppInfo.getVersionCode(context))
            .put("signingCertSha256", AppInfo.getSigningCertSha256(context))
            .put("installer", AppInfo.getInstallerPackage(context) ?: JSONObject.NULL)
            .put("debuggable", AppInfo.isDebuggable(context))
            .put("installId", store.getOrCreateInstallId())
            .put(
                "sdk",
                JSONObject()
                    .put("platform", "android")
                    .put("version", Config.SDK_VERSION)
                    .put("wrapper", wrapper ?: JSONObject.NULL)
            )
            .put("device", JSONObject().put("sdkInt", Build.VERSION.SDK_INT))
            .put("token", token ?: JSONObject.NULL)

        val res = api.postJson("/sdk-handshake", payload) ?: return
        val enabled = res.optBoolean("enabled", true)
        store.setEnabled(enabled)
        if (res.has("flushIntervalSec")) {
            store.setFlushIntervalSec(res.optInt("flushIntervalSec", Config.DEFAULT_FLUSH_SEC))
        }
        if (AppInfo.isDebuggable(context)) {
            Log.i("TesterLoop", res.optString("status", "UNKNOWN").uppercase())
        }
    }

    private fun flushAsync() {
        executor.execute {
            runCatching {
                if (!store.isEnabled()) return@runCatching
                val token = store.getToken()
                    ?: HubTokenClient.fetchToken(context)?.also { store.saveToken(it) }
                    ?: return@runCatching

                val batch = queue.peekBatch(50)
                if (batch.isEmpty()) return@runCatching

                val arr = JSONArray()
                batch.forEach { arr.put(it) }

                val body = JSONObject()
                    .put("appKey", appKey)
                    .put("packageName", context.packageName)
                    .put("installId", store.getOrCreateInstallId())
                    .put("token", token)
                    .put("events", arr)

                val res = api.postJson("/sdk-events", body) ?: return@runCatching
                val accepted = res.optJSONArray("accepted")
                if (accepted != null) {
                    val ids = HashSet<String>(accepted.length())
                    for (i in 0 until accepted.length()) {
                        ids.add(accepted.getString(i))
                    }
                    queue.removeByIds(ids)
                }
                if (res.has("enabled")) {
                    store.setEnabled(res.optBoolean("enabled", true))
                }
            }
        }
    }
}
