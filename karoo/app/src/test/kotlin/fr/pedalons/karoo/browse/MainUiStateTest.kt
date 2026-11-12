package fr.pedalons.karoo.browse

import fr.pedalons.karoo.api.RoutesResponse
import org.junit.Assert.assertEquals
import org.junit.Test

/** The precedence of [MainUiState.screen]. */
class MainUiStateTest {

    private val loaded = BrowseState(response = RoutesResponse(emptyList(), emptyList()))

    private fun ready(
        auth: AuthStatus = AuthStatus.SIGNED_IN,
        isLoading: Boolean = false,
        loadFailed: Boolean = false,
        browse: BrowseState = loaded,
    ) = MainUiState(true, auth, isLoading, loadFailed, browse)

    @Test
    fun notReady_isAlwaysTheSkeleton() {
        assertEquals(MainScreenKind.SKELETON, MainUiState().screen())
        assertEquals(
            MainScreenKind.SKELETON,
            MainUiState(false, AuthStatus.SIGNED_OUT, false, true, loaded).screen(),
        )
    }

    @Test
    fun signedOut_beatsTheError() {
        assertEquals(
            MainScreenKind.CONNECT,
            ready(AuthStatus.SIGNED_OUT, loadFailed = true).screen(),
        )
    }

    @Test
    fun failure_showsTheError_onlyWhenNotLoading() {
        assertEquals(MainScreenKind.ERROR, ready(loadFailed = true).screen())
        assertEquals(MainScreenKind.SKELETON, ready(loadFailed = true, isLoading = true).screen())
    }

    @Test
    fun loadingOrUnknownAuth_isTheSkeleton() {
        assertEquals(MainScreenKind.SKELETON, ready(isLoading = true).screen())
        assertEquals(MainScreenKind.SKELETON, ready(AuthStatus.UNKNOWN).screen())
    }

    @Test
    fun noResponse_isEmpty_elseContent() {
        assertEquals(MainScreenKind.EMPTY, ready(browse = BrowseState()).screen())
        assertEquals(MainScreenKind.CONTENT, ready().screen())
    }
}
