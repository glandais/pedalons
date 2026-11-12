package fr.pedalons.karoo.support

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.KeyEvent
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import com.google.zxing.BinaryBitmap
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import fr.pedalons.karoo.MainActivity
import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.api.TokenResponse
import fr.pedalons.karoo.auth.AuthManager
import java.util.Locale
import java.util.TimeZone
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.robolectric.Shadows.shadowOf

/**
 * What every behaviour test needs: the real [MainActivity] (and the activities it starts) running
 * on Robolectric against a [FakeBackend] standing in for the network, a real [AuthManager] on a
 * real DataStore, and the Karoo hardware keys. Time zone, locale and the 24h setting are frozen.
 *
 * Tests drive and assert through what a rider can see and press (texts, keys, started activities)
 * and what the app sends or stores (HTTP requests, tokens), never through internal state.
 */
abstract class AppTestBase {

    @get:Rule val compose = createEmptyComposeRule()

    val backend = FakeBackend()
    val context: Context = ApplicationProvider.getApplicationContext()
    lateinit var auth: AuthManager
    lateinit var activity: MainActivity
    private val scenarios = mutableListOf<ActivityScenario<*>>()

    private lateinit var savedZone: TimeZone
    private lateinit var savedLocale: Locale

    @Before
    fun baseSetUp() {
        savedZone = TimeZone.getDefault()
        savedLocale = Locale.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("Europe/Paris"))
        Locale.setDefault(Locale.US)
        Settings.System.putString(context.contentResolver, Settings.System.TIME_12_24, "24")

        ShadowKarooSystemService.reset()
        PedalonsApiClient.engineFactoryForTests = { backend.engine() }
        auth = AuthManager(context)
        runBlocking { auth.clearTokens() }
    }

    @After
    fun baseTearDown() {
        scenarios.forEach { runCatching { it.close() } }
        PedalonsApiClient.engineFactoryForTests = null
        runBlocking { auth.clearTokens() }
        TimeZone.setDefault(savedZone)
        Locale.setDefault(savedLocale)
    }

    // === Setup ===

    /**
     * Stores tokens as a successful sign-in would. A negative [expiresIn] gives an expired access
     * token.
     */
    fun signIn(
        access: String = "stored-access",
        refresh: String = "stored-refresh",
        expiresIn: Int = 3600,
    ) = runBlocking { auth.saveTokens(TokenResponse(access, "Bearer", expiresIn, refresh)) }

    fun launch(): MainActivity {
        activity = launchActivity(Intent(context, MainActivity::class.java))
        return activity
    }

    /** Starts any of the app's activities with [intent], as the system would. */
    fun <A : Activity> launchActivity(intent: Intent, expectFinish: Boolean = false): A {
        if (expectFinish) {
            // An activity that closes itself in onCreate is destroyed before the scenario can hand
            // it over.
            val controller =
                org.robolectric.Robolectric.buildActivity<A>(
                    intent.component!!.let { Class.forName(it.className) as Class<A> },
                    intent,
                )
            return controller.setup().get()
        }
        val s = ActivityScenario.launch<A>(intent)
        scenarios += s
        lateinit var started: A
        s.onActivity { started = it }
        return started
    }

    // === Hardware keys ===

    fun key(code: Int) {
        activity.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        activity.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
        compose.waitForIdle()
    }

    fun next(times: Int = 1) = repeat(times) { key(KeyEvent.KEYCODE_NAVIGATE_NEXT) }

    fun previous(times: Int = 1) = repeat(times) { key(KeyEvent.KEYCODE_NAVIGATE_PREVIOUS) }

    fun select() = key(KeyEvent.KEYCODE_NAVIGATE_IN)

    fun back() = key(KeyEvent.KEYCODE_BACK)

    // === Screen assertions ===

    fun waitForText(text: String, timeoutMs: Long = 10_000) {
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()
        }
    }

    fun waitForNoText(text: String, timeoutMs: Long = 10_000) {
        compose.waitUntil(timeoutMs) {
            compose.onAllNodesWithText(text).fetchSemanticsNodes().isEmpty()
        }
    }

    fun hasText(text: String): Boolean =
        compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty()

    fun assertShown(vararg texts: String) {
        for (t in texts) assertTrue("expected on screen: \"$t\"", hasText(t))
    }

    fun assertNotShown(vararg texts: String) {
        for (t in texts) assertTrue("expected NOT on screen: \"$t\"", !hasText(t))
    }

    fun click(text: String) {
        compose.onNodeWithText(text).performClick()
        compose.waitForIdle()
    }

    fun clickDescription(description: String) {
        compose.onNodeWithContentDescription(description).performClick()
        compose.waitForIdle()
    }

    fun hasDescription(description: String) =
        compose.onAllNodesWithContentDescription(description).fetchSemanticsNodes().isNotEmpty()

    /** Decodes the QR code actually rendered on screen (captured pixels, read with ZXing). */
    fun decodeShownQr(): String {
        val bitmap =
            compose.onNodeWithContentDescription("QR Code").captureToImage().asAndroidBitmap()
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        val source = RGBLuminanceSource(bitmap.width, bitmap.height, pixels)
        return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text
    }

    /**
     * Colour at the left edge (border, then background) of the clickable row holding [text], read
     * from the rendered pixels: the selected row is the only one drawn with another colour.
     */
    fun rowBackground(text: String): Int {
        // The row is clickable, so its texts are merged into it: the node found by its text is the
        // row.
        // A row still scrolling into view cannot be captured yet: retry until it settles.
        var image = runCatching { compose.onNodeWithText(text).captureToImage() }
        var tries = 0
        while (image.isFailure && tries++ < 20) {
            Thread.sleep(50)
            compose.waitForIdle()
            image = runCatching { compose.onNodeWithText(text).captureToImage() }
        }
        val bounds = compose.onNodeWithText(text).fetchSemanticsNode().boundsInRoot
        val bitmap =
            image
                .getOrElse { throw AssertionError("cannot capture \"$text\" at $bounds", it) }
                .asAndroidBitmap()
        return bitmap.getPixel(6, bitmap.height / 2)
    }

    /**
     * Asserts that, among the rows identified by their [titles], only the one at [selected] is
     * drawn highlighted (all the others share the same background, the selected one has another).
     */
    fun assertSelectedRow(titles: List<String>, selected: Int) {
        val colours = titles.map { rowBackground(it) }
        val others = colours.filterIndexed { i, _ -> i != selected }.distinct()
        assertEquals("unselected rows share one background: $colours", 1, others.size)
        assertTrue(
            "row $selected ($titles) should be highlighted: $colours",
            colours[selected] != others.single(),
        )
    }

    /** Vertical position of a text, to check display order. */
    fun topOf(text: String): Float =
        compose.onNodeWithText(text).fetchSemanticsNode().boundsInRoot.top

    /** Waits for the Home screen with its three entries. */
    fun waitForHome() = waitForText("My next rides")

    // === Started activities ===

    private var lastStarted: Intent? = null

    /** The activity [activity] started for a result since the last call, null when none. */
    fun startedForResult(): Intent? {
        val next = shadowOf(activity).nextStartedActivityForResult?.intent
        if (next != null) lastStarted = next
        return next
    }

    /** Answers the activity last seen by [startedForResult] with [code]. */
    fun deliverResult(code: Int) {
        val intent = startedForResult() ?: lastStarted
        checkNotNull(intent) { "no activity was started for a result" }
        shadowOf(activity).receiveResult(intent, code, Intent())
        lastStarted = null
        compose.waitForIdle()
    }

    fun assertFinishing() = assertTrue("the activity should be finishing", activity.isFinishing)

    fun assertNotFinishing() =
        assertTrue("the activity should not be finishing", !activity.isFinishing)

    fun assertStartedClass(intent: Intent?, cls: Class<out Activity>) {
        assertEquals(cls.name, intent?.component?.className)
    }
}
