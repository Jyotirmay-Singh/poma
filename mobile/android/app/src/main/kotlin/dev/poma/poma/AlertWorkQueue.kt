package dev.poma.poma

import java.util.concurrent.Executors

/** Serial one-shot native work; idle threads block without polling or wake locks. */
internal object AlertWorkQueue {
    private val executor = Executors.newSingleThreadExecutor { work ->
        Thread(work, "poma-alert-work").apply { isDaemon = true }
    }

    fun execute(work: () -> Unit) {
        executor.execute(work)
    }
}
