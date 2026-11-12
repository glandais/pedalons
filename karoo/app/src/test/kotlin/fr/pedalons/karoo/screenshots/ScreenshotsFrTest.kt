package fr.pedalons.karoo.screenshots

import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "fr-w256dp-h427dp-300dpi")
class ScreenshotsFrTest : ScreenshotCases("fr")
