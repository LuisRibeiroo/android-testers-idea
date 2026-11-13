package io.testerloop.sdk.internal

import android.content.Context
import org.json.JSONObject
import java.io.File

internal class EventQueue(private val file: File) {
    constructor(context: Context) : this(File(context.filesDir, "testerloop_events.jsonl"))

    @Synchronized
    fun enqueue(event: JSONObject) {
        runCatching {
            val lines = readAllLines().toMutableList()
            lines.add(event.toString())
            while (lines.size > Config.MAX_QUEUE_SIZE) {
                lines.removeAt(0)
            }
            writeAllLines(lines)
        }
    }

    @Synchronized
    fun peekBatch(limit: Int = 50): List<JSONObject> {
        return runCatching {
            readAllLines()
                .take(limit)
                .mapNotNull { line -> runCatching { JSONObject(line) }.getOrNull() }
        }.getOrDefault(emptyList())
    }

    @Synchronized
    fun removeByIds(ids: Set<String>) {
        if (ids.isEmpty()) return
        runCatching {
            val remaining = readAllLines().filter { line ->
                val id = runCatching { JSONObject(line).optString("id") }.getOrNull()
                id == null || !ids.contains(id)
            }
            writeAllLines(remaining)
        }
    }

    @Synchronized
    fun size(): Int = readAllLines().size

    private fun readAllLines(): List<String> {
        if (!file.exists()) return emptyList()
        return file.readLines().filter { it.isNotBlank() }
    }

    private fun writeAllLines(lines: List<String>) {
        file.parentFile?.mkdirs()
        if (lines.isEmpty()) {
            file.delete()
        } else {
            file.writeText(lines.joinToString("\n") + "\n")
        }
    }
}
