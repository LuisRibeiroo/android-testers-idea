package io.testerloop.sdk.internal

import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

internal class ApiClient(private val baseUrl: String) {

    fun postJson(path: String, payload: JSONObject): JSONObject? {
        return runCatching {
            val url = URL("${baseUrl.trimEnd('/')}$path")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 8000
                readTimeout = 8000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(payload.toString())
            }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val body = stream?.use { s ->
                BufferedReader(InputStreamReader(s, Charsets.UTF_8)).readText()
            } ?: ""
            conn.disconnect()
            if (code in 200..299 && body.isNotBlank()) JSONObject(body) else null
        }.getOrNull()
    }
}
