package dev.poma.poma

import org.junit.Assert.*
import org.junit.Test

class PomaAudioPolicyTest {
    @Test fun mediaIdentityNeverOverlapsPositiveCompletionIds() {
        assertTrue(PomaAudioPolicy.NOTIFICATION_ID < 0)
        assertNotEquals(1124, PomaAudioPolicy.NOTIFICATION_ID)
        assertEquals(4, PomaAudioPolicy.assets.drop(1).distinct().size)
    }
    @Test fun preparationRequiresEveryIdentityAndAnUnexpiredDeadline() {
        assertTrue(PomaAudioPolicy.current(1, 8, 3, 100, 1, 8, 3, 99))
        assertFalse(PomaAudioPolicy.current(1, 8, 3, 100, 2, 8, 3, 99))
        assertFalse(PomaAudioPolicy.current(1, 8, 3, 100, 1, 9, 3, 99))
        assertFalse(PomaAudioPolicy.current(1, 8, 3, 100, 1, 8, 4, 99))
        assertFalse(PomaAudioPolicy.current(1, 8, 3, 100, 1, 8, 3, 100))
        assertFalse(PomaAudioPolicy.current(1, 8, 3, 100, 1, 8, 3, -1))
    }
}
