package dev.poma.poma

@androidx.annotation.Keep
object PomaAudioNative {
    init { System.loadLibrary("poma_focus_audio"); attach() }
    @JvmStatic private external fun attach()
    @JvmStatic external fun owner(): Long
    @JvmStatic external fun generation(): Long
    @JvmStatic external fun epoch(): Long
    @JvmStatic external fun now(): Long
    @JvmStatic external fun busy(): Long
    @JvmStatic external fun playing(): Long
    @JvmStatic external fun interrupt(kind: Int)
    @JvmStatic external fun reconcile()
    @JvmStatic external fun prepare(owner: Long, generation: Long, epoch: Long, deadline: Long, sound: Int, data: ByteArray): Long
    @JvmStatic external fun start(owner: Long, source: Long, generation: Long, epoch: Long, deadline: Long, gain: Double): Int
    @JvmStatic external fun release(owner: Long, source: Long)
    @JvmStatic fun event(kind: Int, owner: Long, generation: Long, epoch: Long) {
        PomaAudioBridge.instance?.nativeEvent(kind, owner, generation, epoch)
    }
}
