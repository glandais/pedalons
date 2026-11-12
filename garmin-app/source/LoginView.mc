using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.ScanCode;

/**
 * View displayed when user needs to log in.
 * Shows the Device Code Flow: a QR code of the verification URL with the code in it, then the
 * site and the user code, which the web page asks to compare before pairing (ledger SEC-2).
 *
 * The QR code comes from the firmware where it can make one (Toybox.ScanCode, API 6.0.0), and
 * from QrCode.mc everywhere else, or when the firmware refuses.
 */
class LoginView extends WatchUi.View {
    // Quiet zone around the QR code, in modules (the standard asks for 4)
    private const QUIET_ZONE = 4;
    // Beyond this a QR code fills a 1050 screen without scanning any better
    private const MAX_MODULE_PX = 8;
    // The largest symbol QrCode.mc makes, quiet zone included: the yardstick for the native one
    private const MAX_MODULES = 33 + 2 * 4;

    private var _userCode;
    private var _host;
    // The text to encode; the code itself is made at the first draw, once the room is known
    private var _qrText;
    private var _qrReady;
    // Native code: the bitmap and the side of its white square
    private var _qrBitmap;
    private var _qrBox;
    // Fallback: the modules from QrCode.mc
    private var _qrModules;
    private var _statusText;
    private var _isPolling;

    function initialize() {
        View.initialize();
        _userCode = null;
        _host = null;
        _qrText = null;
        _qrReady = false;
        _qrBitmap = null;
        _qrBox = 0;
        _qrModules = null;
        _statusText = "";
        _isPolling = false;
    }

    /**
     * Set the code to display, with the URLs the backend returned for this domain.
     */
    function setDeviceCode(code, verificationUri, verificationUriComplete) {
        _userCode = code;
        _host = hostOf(verificationUri);
        _qrText = verificationUriComplete;
        _qrReady = false;
        _qrBitmap = null;
        _qrModules = null;
        _isPolling = true;
        _statusText = WatchUi.loadResource(Rez.Strings.Waiting);
        WatchUi.requestUpdate();
    }

    /**
     * Set the status text.
     */
    function setStatus(text) {
        _statusText = text;
        WatchUi.requestUpdate();
    }

    /**
     * Get whether we're polling.
     */
    function isPolling() {
        return _isPolling;
    }

    function onLayout(dc) {
        // No layout XML, we draw directly
    }

    function onUpdate(dc) {
        dc.setColor(Theme.text(), Theme.background());
        dc.clear();

        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        if (_userCode != null) {
            var label = WatchUi.loadResource(Rez.Strings.GoTo);
            var textTop = centerY - 70;
            var qrTop = 6;
            var textHeight =
                2 * dc.getFontHeight(Graphics.FONT_TINY) +
                dc.getFontHeight(Graphics.FONT_SMALL) +
                dc.getFontHeight(Graphics.FONT_LARGE) +
                22;
            var room = dc.getHeight() - textHeight - 2 * qrTop;
            if (dc.getWidth() < room) {
                room = dc.getWidth();
            }
            var box = drawQr(dc, centerX, qrTop, room);
            if (box > 0) {
                label = WatchUi.loadResource(Rez.Strings.ScanOrGoTo);
                textTop = qrTop + box + 6;
            }

            var layout = new VerticalLayout(textTop, 4);
            layout.draw(dc, centerX, Graphics.FONT_TINY, label, null, Theme.muted());
            if (_host != null) {
                layout.draw(dc, centerX, Graphics.FONT_SMALL, _host, null, Theme.text());
            }
            layout.skip(10);
            layout.draw(dc, centerX, Graphics.FONT_LARGE, _userCode, null, Theme.text());
            layout.draw(dc, centerX, Graphics.FONT_TINY, _statusText, null, Theme.accent());
        } else {
            var layout = new VerticalLayout(centerY - 30, 60);
            layout.draw(
                dc,
                centerX,
                Graphics.FONT_MEDIUM,
                WatchUi.loadResource(Rez.Strings.LoginRequired),
                null,
                Theme.accent()
            );
            layout.draw(
                dc,
                centerX,
                Graphics.FONT_TINY,
                WatchUi.loadResource(Rez.Strings.PressSelectToLogin),
                null,
                Theme.muted()
            );
        }
    }

    /**
     * Draw the QR code in a square of at most `room` pixels: the firmware's when it makes one,
     * QrCode.mc's otherwise. Returns the side of the white square, 0 when there is no code to
     * show (the view then falls back to the site and the code alone).
     */
    private function drawQr(dc, centerX, top, room) {
        if (_qrText == null) {
            return 0;
        }
        if (!_qrReady) {
            _qrReady = true;
            _qrBitmap = nativeQrCode(room);
            if (_qrBitmap == null) {
                _qrModules = QrCode.encode(_qrText);
            }
        }
        if (_qrBitmap != null) {
            var left = centerX - _qrBox / 2;
            var margin = _qrBox / 10;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(left, top, _qrBox, _qrBox);
            dc.drawBitmap(left + margin, top + margin, _qrBitmap);
            return _qrBox;
        }
        if (_qrModules != null) {
            var modulePx = moduleSize(room);
            if (modulePx > 0) {
                return drawQrCode(dc, centerX, top, modulePx);
            }
        }
        return 0;
    }

    /**
     * The firmware's QR code, or null: no Toybox.ScanCode on this device (before API 6.0.0), a
     * room too small to scan, or a firmware that refuses (text too long, no graphics memory).
     * Same error correction as QrCode.mc (level L). The image fills 4/5 of the white square,
     * which leaves the quiet zone whether or not the firmware draws one of its own.
     */
    private function nativeQrCode(room) {
        if (!(Toybox has :ScanCode)) {
            return null;
        }
        var box = room;
        if (box > MAX_MODULES * MAX_MODULE_PX) {
            box = MAX_MODULES * MAX_MODULE_PX;
        }
        if (box < MAX_MODULES * 2) {
            return null;
        }
        try {
            var bitmap = ScanCode.createQrCodeImage(
                _qrText,
                ScanCode.QR_CODE_ECC_LOW,
                box - 2 * (box / 10),
                null
            );
            _qrBox = box;
            return bitmap;
        } catch (e) {
            return null;
        }
    }

    /**
     * Largest whole module size that fits the room, 0 below 2 px (too small to scan).
     */
    private function moduleSize(room) {
        var modules = QrCode.sideOf(_qrModules) + 2 * QUIET_ZONE;
        var size = room / modules;
        if (size > MAX_MODULE_PX) {
            size = MAX_MODULE_PX;
        }
        return size >= 2 ? size : 0;
    }

    /**
     * Draw the QR code on a white square (its quiet zone), dark runs of a row as one rectangle.
     * Returns the side of the square in pixels.
     */
    private function drawQrCode(dc, centerX, top, modulePx) {
        var modules = _qrModules as Lang.ByteArray;
        var side = QrCode.sideOf(modules);
        var box = (side + 2 * QUIET_ZONE) * modulePx;
        var left = centerX - box / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillRectangle(left, top, box, box);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        var origin = QUIET_ZONE * modulePx;
        for (var y = 0; y < side; y++) {
            var x = 0;
            while (x < side) {
                if (modules[y * side + x] == 1) {
                    var start = x;
                    while (x < side && modules[y * side + x] == 1) {
                        x++;
                    }
                    dc.fillRectangle(
                        left + origin + start * modulePx,
                        top + origin + y * modulePx,
                        (x - start) * modulePx,
                        modulePx
                    );
                } else {
                    x++;
                }
            }
        }
        return box;
    }

    /**
     * "https://www.pedalons.fr/garmin" -> "www.pedalons.fr/garmin": what the rider would type.
     */
    private function hostOf(uri) {
        if (uri == null) {
            return null;
        }
        var scheme = uri.find("://");
        return scheme != null ? uri.substring(scheme + 3, uri.length()) : uri;
    }
}

/**
 * Input delegate for LoginView.
 */
class LoginDelegate extends WatchUi.BehaviorDelegate {
    private var _app;

    function initialize(app) {
        BehaviorDelegate.initialize();
        _app = app;
    }

    function onSelect() {
        // Start Device Code Flow
        _app.startDeviceCodeFlow();
        return true;
    }

    function onBack() {
        // Exit app
        System.exit();
    }
}
