package fr.pedalons.karoo.auth

import com.google.zxing.BinaryBitmap
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/** The QR codes of the sign-in and Hammerhead screens encode exactly the URL they are given. */
@RunWith(RobolectricTestRunner::class)
class QrCodeTest {

    private fun decode(content: String): String {
        val bitmap = generateQrCode(content)
        assertNotNull(bitmap)
        val pixels = IntArray(bitmap!!.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        val source = RGBLuminanceSource(bitmap.width, bitmap.height, pixels)
        return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text
    }

    @Test
    fun is140PixelsSquare() {
        val bitmap = generateQrCode("https://www.pedalons.fr/karoo?code=ABC123")!!
        assertEquals(140, bitmap.width)
        assertEquals(140, bitmap.height)
    }

    @Test
    fun theVerificationUriRoundTrips() {
        assertEquals(
            "https://www.pedalons.fr/karoo?code=ABC123",
            decode("https://www.pedalons.fr/karoo?code=ABC123"),
        )
    }

    @Test
    fun theHammerheadResumeUrlRoundTrips() {
        assertEquals(
            "https://www.pedalons.fr/karoo/hammerhead",
            decode("https://www.pedalons.fr/karoo/hammerhead"),
        )
    }

    @Test
    fun contentTooLongForAQrIsNullNotACrash() {
        assertEquals(null, generateQrCode("x".repeat(10_000)))
    }
}
