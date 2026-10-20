package dev.poma.poma

import org.junit.Assert.*
import org.junit.Test

class AlertPolicyTest {
    @Test fun sameBootIgnoresForwardAndBackwardWallChanges() {
        for (wall in listOf(-9_000_000L, 0L, 9_000_000L)) {
            assertEquals(400L, AlertPolicy.remaining(7, 7, 600, 1000, wall, 800, 1000))
        }
    }
    @Test fun elapsedDeadlineCanBeOverdueAfterSleep() {
        assertEquals(-50L, AlertPolicy.remaining(7, 7, 1050, 1000, 10, 800, 1000))
    }
    @Test fun rebootNeverComparesDifferentBootRelativeClocks() {
        assertEquals(300L, AlertPolicy.remaining(8, 7, 5, 1000, 500, 800, 1000))
    }
    @Test fun unavailableBootIdentityUsesBoundedUtc() {
        assertEquals(200L, AlertPolicy.remaining(null, null, 600, 1000, 0, 800, 200))
    }
    @Test fun overdueRebootDoesNotRescheduleFutureWork() {
        assertEquals(-100L, AlertPolicy.remaining(8, 7, 5, 1000, 900, 800, 1000))
    }
    @Test fun oldRunAndOldResumeGenerationAreRejected() {
        assertFalse(AlertPolicy.matches("old", 4, "new", 4))
        assertFalse(AlertPolicy.matches("same", 3, "same", 4))
        assertFalse(AlertPolicy.matches("", 4, "", 4))
        assertFalse(AlertPolicy.matches("same", 0, "same", 0))
        assertTrue(AlertPolicy.matches("same", 4, "same", 4))
    }
}
