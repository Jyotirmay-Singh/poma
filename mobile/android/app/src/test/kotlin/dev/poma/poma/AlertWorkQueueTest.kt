package dev.poma.poma

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class AlertWorkQueueTest {
    @Test fun blockedNativeReadLeavesCallerFreeToCompleteDatabaseReply() {
        val entered = CountDownLatch(1)
        val databaseReply = CountDownLatch(1)
        val finished = CountDownLatch(1)
        val failure = AtomicReference<String?>()
        val caller = Thread.currentThread()
        AlertWorkQueue.execute {
            if (Thread.currentThread() === caller) failure.set("Native read ran on caller")
            entered.countDown()
            // Models a native read waiting for a Dart/sqflite transaction whose
            // platform-channel reply must be serviced by the caller/main thread.
            if (!databaseReply.await(2, TimeUnit.SECONDS)) failure.set("Caller could not reply")
            finished.countDown()
        }
        assertTrue(entered.await(2, TimeUnit.SECONDS))
        databaseReply.countDown()
        assertTrue(finished.await(2, TimeUnit.SECONDS))
        assertNull(failure.get())
    }

    @Test fun bridgeAndReceiverWorkStayOrderedWhileCallerRemainsResponsive() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val finished = CountDownLatch(1)
        val order = mutableListOf<String>()
        AlertWorkQueue.execute {
            entered.countDown()
            release.await(2, TimeUnit.SECONDS)
            order.add("commit")
        }
        assertTrue(entered.await(2, TimeUnit.SECONDS))
        AlertWorkQueue.execute {
            order.add("delivery")
            finished.countDown()
        }
        release.countDown()
        assertTrue(finished.await(2, TimeUnit.SECONDS))
        assertEquals(listOf("commit", "delivery"), order)
    }
}
