package fr.pedalons.karoo.auth

import fr.pedalons.karoo.data.HammerheadStatus
import fr.pedalons.karoo.data.PedalonsRepository
import kotlinx.coroutines.delay

/**
 * Follows the account until Hammerhead shows up. A failed read (network, token, refresh) just waits
 * for the next round, and the session is never cleared here. Like [DeviceCodeLogin.run],
 * [awaitLinked] belongs in a `LaunchedEffect`.
 */
internal class HammerheadLinkWatcher(private val repo: PedalonsRepository) {

    /** Checks now, then every [GpsConnectActivity.POLL_INTERVAL_MS], and returns once linked. */
    suspend fun awaitLinked() {
        while (repo.hammerheadStatus() != HammerheadStatus.LINKED) {
            delay(GpsConnectActivity.POLL_INTERVAL_MS)
        }
    }
}
