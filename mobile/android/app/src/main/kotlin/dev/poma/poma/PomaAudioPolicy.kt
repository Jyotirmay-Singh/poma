package dev.poma.poma

/** Pure identity/time policy, also exercised without an Android device. */
object PomaAudioPolicy {
    const val NOTIFICATION_ID = -1124
    const val CHANNEL = "poma_focus_sounds_v1"
    const val MAX_ASSET_BYTES = 4 * 1024 * 1024
    val assets = listOf("", "tibetan_bells.ogg", "waterfall.ogg", "ocean_waves.ogg", "forest_birds.ogg")
    val titles = listOf("", "Tibetan bells", "Waterfall", "Ocean waves", "Forest birds")
    fun current(owner: Long, generation: Long, epoch: Long, deadline: Long,
                currentOwner: Long, currentGeneration: Long, currentEpoch: Long, now: Long): Boolean =
        owner == currentOwner && generation == currentGeneration && epoch == currentEpoch && now >= 0 && deadline > now
}
