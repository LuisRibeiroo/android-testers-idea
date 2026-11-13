package io.testerloop.sdk

import io.testerloop.sdk.internal.Config
import io.testerloop.sdk.internal.EventQueue
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import java.nio.file.Files

class EventQueueTest {
    @Test
    fun enqueueRespectsFifoLimitAndRemovesById() {
        val tempDir = Files.createTempDirectory("tl_queue_test").toFile()
        val queueFile = tempDir.resolve("events.jsonl")
        val queue = EventQueue(queueFile)

        for (i in 1..(Config.MAX_QUEUE_SIZE + 5)) {
            queue.enqueue(JSONObject().put("id", "ev_$i").put("type", "ping"))
        }

        assertEquals(Config.MAX_QUEUE_SIZE, queue.size())
        val first = queue.peekBatch(1).first()
        assertEquals("ev_6", first.getString("id"))

        queue.removeByIds(setOf("ev_6", "ev_7"))
        assertEquals(Config.MAX_QUEUE_SIZE - 2, queue.size())
        tempDir.deleteRecursively()
    }
}
