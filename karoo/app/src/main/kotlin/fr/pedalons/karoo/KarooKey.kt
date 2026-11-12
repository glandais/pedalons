package fr.pedalons.karoo

import android.view.KeyEvent

/** The four hardware keys of the Karoo the app acts on. */
enum class KarooKey {
    NEXT,
    PREVIOUS,
    SELECT,
    BACK;

    companion object {
        /** The key behind an Android [keyCode], null for any other key. */
        fun fromKeyCode(keyCode: Int): KarooKey? =
            when (keyCode) {
                KeyEvent.KEYCODE_NAVIGATE_NEXT -> NEXT
                KeyEvent.KEYCODE_NAVIGATE_PREVIOUS -> PREVIOUS
                KeyEvent.KEYCODE_NAVIGATE_IN -> SELECT
                KeyEvent.KEYCODE_BACK -> BACK
                else -> null
            }
    }
}
