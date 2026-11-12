using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

/**
 * Main Pédalons application for Garmin Connect IQ.
 * Allows users to browse and download routes from their teams.
 * Uses Device Code Flow (RFC 8628) for authentication.
 */
class PedalonsApp extends Application.AppBase {
    private var _authManager;
    private var _apiClient;
    private var _loginView;
    private var _pollTimer;
    private var _deviceCode;

    function initialize() {
        AppBase.initialize();
        _authManager = new AuthManager();
        _apiClient = new ApiClient(_authManager);
        _loginView = null;
        _pollTimer = null;
        _deviceCode = null;
    }

    function onStart(state) {}

    function onStop(state) {
        // Stop polling if active
        if (_pollTimer != null) {
            _pollTimer.stop();
            _pollTimer = null;
        }
    }

    // The Edge went to or from night mode: the drawn views follow (Theme.mc)
    function onNightModeChanged() {
        WatchUi.requestUpdate();
    }

    function getInitialView() {
        // Check if we have a valid token
        if (_authManager.hasValidToken()) {
            return showRouteList();
        } else {
            return showLoginView();
        }
    }

    /**
     * Show the login view prompting user to authenticate.
     */
    function showLoginView() {
        _loginView = new LoginView();
        var delegate = new LoginDelegate(self);
        return [_loginView, delegate];
    }

    /**
     * Show the route list view.
     */
    function showRouteList() {
        _loginView = null;
        var view = new PedalonsView(_apiClient);
        var delegate = new PedalonsDelegate(view);
        return [view, delegate];
    }

    /**
     * Start the Device Code Flow.
     * Requests a device code, displays it, and starts polling.
     */
    function startDeviceCodeFlow() {
        _apiClient.requestDeviceCode(method(:onDeviceCodeReceived));
    }

    /**
     * Callback when device code is received.
     */
    function onDeviceCodeReceived(result) {
        if (result.get("success") == true) {
            _deviceCode = result.get("deviceCode");
            var userCode = result.get("userCode");
            var expiresIn = result.get("expiresIn");
            var interval = result.get("interval");

            // Save device code for potential resume
            _authManager.saveDeviceCode(_deviceCode, userCode, expiresIn);

            // Update the login view to show the code
            if (_loginView != null) {
                _loginView.setDeviceCode(
                    userCode,
                    result.get("verificationUri"),
                    result.get("verificationUriComplete")
                );
            }

            // Start polling timer
            // Connect IQ Timer expects milliseconds
            var pollInterval = interval * 1000;
            if (pollInterval < 5000) {
                pollInterval = 5000; // Minimum 5 seconds per RFC 8628
            }

            _pollTimer = new Timer.Timer();
            _pollTimer.start(method(:pollForToken), pollInterval, true);
        } else {
            // Request failed, show error
            WatchUi.switchToView(
                new ErrorView(WatchUi.loadResource(Rez.Strings.ConnectionError)),
                new ErrorDelegate(self),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }

    /**
     * Poll for token authorization.
     * Called periodically by the timer.
     */
    function pollForToken() as Void {
        // Check if device code expired
        if (_authManager.isDeviceCodeExpired()) {
            stopPolling();
            _authManager.clearDeviceCode();

            if (_loginView != null) {
                _loginView.setStatus(WatchUi.loadResource(Rez.Strings.CodeExpired));
            }
            return;
        }

        // Poll for token
        _apiClient.pollForToken(_deviceCode, method(:onPollResponse));
    }

    /**
     * Callback when poll response is received.
     */
    function onPollResponse(result) {
        if (result.get("success") == true) {
            // Success! Tokens received and saved
            stopPolling();
            _authManager.clearDeviceCode();

            // Switch to route list
            var viewPair = showRouteList();
            WatchUi.switchToView(viewPair[0], viewPair[1], WatchUi.SLIDE_IMMEDIATE);
            return;
        }

        if (result.get("pending") == true) {
            // Normal state - authorization pending, keep polling
            return;
        }

        if (result.get("expired") == true) {
            // Device code expired
            stopPolling();
            _authManager.clearDeviceCode();

            if (_loginView != null) {
                _loginView.setStatus(WatchUi.loadResource(Rez.Strings.CodeExpired));
            }
            return;
        }

        // Other error - stop polling and show error
        stopPolling();

        if (_loginView != null) {
            _loginView.setStatus(WatchUi.loadResource(Rez.Strings.AuthError));
        }
    }

    /**
     * Stop the polling timer.
     */
    private function stopPolling() {
        if (_pollTimer != null) {
            _pollTimer.stop();
            _pollTimer = null;
        }
    }

    /**
     * Get the auth manager instance.
     */
    function getAuthManager() {
        return _authManager;
    }

    /**
     * Get the API client instance.
     */
    function getApiClient() {
        return _apiClient;
    }
}
