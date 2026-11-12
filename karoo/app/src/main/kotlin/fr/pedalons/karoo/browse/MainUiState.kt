package fr.pedalons.karoo.browse

import io.hammerhead.karooext.models.UserProfile

internal enum class AuthStatus {
    UNKNOWN,
    SIGNED_IN,
    SIGNED_OUT,
}

internal enum class MainScreenKind {
    SKELETON,
    CONNECT,
    ERROR,
    EMPTY,
    CONTENT,
}

/** What the main screen shows, all of it. */
internal data class MainUiState(
    /** The Karoo System Service is connected: until then keys are ignored. */
    val karooReady: Boolean = false,
    val auth: AuthStatus = AuthStatus.UNKNOWN,
    val isLoading: Boolean = true,
    /** A load failed with a message (a failure without one is not shown as an error). */
    val loadFailed: Boolean = false,
    val browse: BrowseState = BrowseState(),
    val userProfile: UserProfile? = null,
) {
    fun screen(): MainScreenKind =
        when {
            !karooReady -> MainScreenKind.SKELETON
            auth == AuthStatus.SIGNED_OUT -> MainScreenKind.CONNECT
            loadFailed && !isLoading -> MainScreenKind.ERROR
            isLoading || auth == AuthStatus.UNKNOWN -> MainScreenKind.SKELETON
            browse.response == null -> MainScreenKind.EMPTY
            else -> MainScreenKind.CONTENT
        }
}
