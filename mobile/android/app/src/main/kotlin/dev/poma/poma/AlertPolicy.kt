package dev.poma.poma

/** Pure policy shared by receivers and JVM tests; no wall-clock countdown. */
object AlertPolicy {
    fun remaining(
        boot: Int?, savedBoot: Int?, elapsedNow: Long, elapsedDeadline: Long,
        utcNow: Long, utcDeadline: Long, maximum: Long
    ): Long = if (boot != null && boot == savedBoot) {
        elapsedDeadline - elapsedNow
    } else {
        minOf(maximum, utcDeadline - utcNow)
    }

    fun matches(run: String, generation: Long, expectedRun: String, expectedGeneration: Long): Boolean =
        run.isNotEmpty() && generation > 0 && run == expectedRun && generation == expectedGeneration
}
