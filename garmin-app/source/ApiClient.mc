using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Position;

/**
 * API client for Pédalons backend.
 * Handles all HTTP communication including authentication via Device Code Flow.
 */
class ApiClient {
    // TODO: Update this URL for production
    public static const BASE_URL = "https://www.pedalons.fr";
    public static const API_BASE_URL = BASE_URL + "/api";

    private var _authManager;
    private var _routesCallback;
    private var _downloadCallback;
    private var _tokenCallback;
    private var _deviceCodeCallback;
    private var _pendingDownload;

    function initialize(authManager) {
        _authManager = authManager;
        _routesCallback = null;
        _downloadCallback = null;
        _tokenCallback = null;
        _deviceCodeCallback = null;
        _pendingDownload = null;
    }

    /**
     * Request a device code for Device Code Flow authentication.
     */
    function requestDeviceCode(callback) as Void {
        _deviceCodeCallback = callback;

        var url = API_BASE_URL + "/device/oauth/device";
        var params = {
            "clientId" => "garmin",
        };

        Communications.makeWebRequest(
            url,
            params,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onDeviceCodeResponse)
        );
    }

    /**
     * Handle device code API response.
     */
    function onDeviceCodeResponse(
        responseCode as Lang.Number,
        data as Lang.Dictionary or Lang.String or Null
    ) as Void {
        var callback = _deviceCodeCallback;
        _deviceCodeCallback = null;

        if (responseCode == 200 && data != null && data instanceof Lang.Dictionary) {
            var dict = data as Lang.Dictionary;
            var deviceCode = dict.get("deviceCode");
            var userCode = dict.get("userCode");
            var verificationUri = dict.get("verificationUri");
            var verificationUriComplete = dict.get("verificationUriComplete");
            var expiresIn = dict.get("expiresIn");
            var interval = dict.get("interval");

            if (deviceCode != null && userCode != null) {
                if (callback != null) {
                    callback.invoke({
                        "success" => true,
                        "deviceCode" => deviceCode,
                        "userCode" => userCode,
                        "verificationUri" => verificationUri,
                        "verificationUriComplete" => verificationUriComplete,
                        "expiresIn" => expiresIn,
                        "interval" => interval,
                    });
                }
                return;
            }
        }

        if (callback != null) {
            callback.invoke({
                "success" => false,
            });
        }
    }

    /**
     * Poll for token using device code.
     */
    function pollForToken(deviceCode, callback) as Void {
        _tokenCallback = callback;

        var url = API_BASE_URL + "/device/oauth/token";
        var params = {
            "grantType" => "urn:ietf:params:oauth:grant-type:device_code",
            "deviceCode" => deviceCode,
        };

        Communications.makeWebRequest(
            url,
            params,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onPollTokenResponse)
        );
    }

    /**
     * Handle polling token response.
     */
    function onPollTokenResponse(
        responseCode as Lang.Number,
        data as Lang.Dictionary or Lang.String or Null
    ) as Void {
        var callback = _tokenCallback;
        _tokenCallback = null;

        if (responseCode == 200 && data != null && data instanceof Lang.Dictionary) {
            var dict = data as Lang.Dictionary;
            var accessToken = dict.get("accessToken");
            var refreshToken = dict.get("refreshToken");
            var expiresIn = dict.get("expiresIn");

            if (accessToken != null && expiresIn != null) {
                _authManager.saveTokens(accessToken, refreshToken, expiresIn);
                if (callback != null) {
                    callback.invoke({
                        "success" => true,
                    });
                }
                return;
            }
        }

        // Check for specific error codes
        if (responseCode == 400 && data != null && data instanceof Lang.Dictionary) {
            var dict = data as Lang.Dictionary;
            var errorCode = dict.get("code");

            if (errorCode != null && errorCode.equals("AUTHORIZATION_PENDING")) {
                // Normal state - authorization pending
                if (callback != null) {
                    callback.invoke({
                        "success" => false,
                        "pending" => true,
                    });
                }
                return;
            }

            if (errorCode != null && errorCode.equals("TOKEN_EXPIRED")) {
                // Device code expired
                if (callback != null) {
                    callback.invoke({
                        "success" => false,
                        "expired" => true,
                    });
                }
                return;
            }
        }

        if (callback != null) {
            callback.invoke({
                "success" => false,
            });
        }
    }

    /**
     * Refresh the access token using refresh token.
     */
    function refreshToken(callback) as Void {
        _tokenCallback = callback;

        var refreshToken = _authManager.getRefreshToken();
        if (refreshToken == null) {
            if (callback != null) {
                callback.invoke(false);
            }
            return;
        }

        var url = API_BASE_URL + "/device/oauth/token";
        var params = {
            "grantType" => "refresh_token",
            "refreshToken" => refreshToken,
        };

        Communications.makeWebRequest(
            url,
            params,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onTokenResponse)
        );
    }

    /**
     * Handle token API response (for refresh).
     */
    function onTokenResponse(
        responseCode as Lang.Number,
        data as Lang.Dictionary or Lang.String or Null
    ) as Void {
        var callback = _tokenCallback;
        _tokenCallback = null;

        if (responseCode == 200 && data != null && data instanceof Lang.Dictionary) {
            var accessToken = (data as Lang.Dictionary).get("accessToken");
            var refreshToken = (data as Lang.Dictionary).get("refreshToken");
            var expiresIn = (data as Lang.Dictionary).get("expiresIn");

            if (accessToken != null && expiresIn != null) {
                _authManager.saveTokens(accessToken, refreshToken, expiresIn);
                if (callback != null) {
                    callback.invoke(true);
                }
                return;
            }
        }

        if (callback != null) {
            callback.invoke(false);
        }
    }

    /**
     * Fetch routes for the authenticated user.
     */
    function fetchRoutes(callback) as Void {
        _routesCallback = callback;

        // Check if we need to refresh token first
        if (_authManager.needsRefresh()) {
            refreshToken(method(:onRefreshForRoutes));
            return;
        }

        doFetchRoutes();
    }

    /**
     * Callback after refreshing token for routes fetch.
     */
    function onRefreshForRoutes(success) as Void {
        if (success) {
            doFetchRoutes();
        } else {
            var callback = _routesCallback;
            _routesCallback = null;
            if (callback != null) {
                callback.invoke(null);
            }
        }
    }

    /**
     * Actually fetch routes from API.
     */
    private function doFetchRoutes() as Void {
        var url = API_BASE_URL + "/device/routes";

        // Try to get current position for proximity sorting
        var position = Position.getInfo();
        if (position != null && position.accuracy != Position.QUALITY_NOT_AVAILABLE) {
            var coords = position.position.toDegrees();
            url = url + "?lat=" + coords[0] + "&lon=" + coords[1];
        }

        var accessToken = _authManager.getAccessToken();

        Communications.makeWebRequest(
            url,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Authorization" => "Bearer " + accessToken,
                    "Accept" => "application/json",
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onRoutesResponse)
        );
    }

    /**
     * Handle routes API response.
     * Parses the new structured response with rides and routes.
     */
    function onRoutesResponse(
        responseCode as Lang.Number,
        data as Lang.Dictionary or Lang.String or Null
    ) as Void {
        var callback = _routesCallback;
        _routesCallback = null;

        if (responseCode == 200 && data != null && data instanceof Lang.Dictionary) {
            var dict = data as Lang.Dictionary;
            var result = {
                "rides" => [],
                "routes" => [],
                "registeredGroups" => [],
            };

            // Parse rides
            var rawRides = dict.get("rides");
            if (rawRides != null && rawRides instanceof Lang.Array) {
                var rides = [];
                for (var i = 0; i < rawRides.size(); i++) {
                    var raw = rawRides[i];
                    if (raw instanceof Lang.Dictionary) {
                        rides.add(parseRideDto(raw as Lang.Dictionary));
                    }
                }
                result.put("rides", rides);
            }

            // Parse standalone routes
            var rawRoutes = dict.get("routes");
            if (rawRoutes != null && rawRoutes instanceof Lang.Array) {
                var routes = [];
                for (var i = 0; i < rawRoutes.size(); i++) {
                    var raw = rawRoutes[i];
                    if (raw instanceof Lang.Dictionary) {
                        routes.add(parseStandaloneRouteDto(raw as Lang.Dictionary));
                    }
                }
                result.put("routes", routes);
            }

            // Parse the groups the user is registered in, absent from an older backend
            var rawGroups = dict.get("registeredGroups");
            if (rawGroups != null && rawGroups instanceof Lang.Array) {
                var groups = [];
                for (var i = 0; i < rawGroups.size(); i++) {
                    var raw = rawGroups[i];
                    if (raw instanceof Lang.Dictionary) {
                        groups.add(parseRegisteredGroupDto(raw as Lang.Dictionary));
                    }
                }
                result.put("registeredGroups", groups);
            }

            if (callback != null) {
                callback.invoke(result);
            }
            return;
        }

        // If 401, clear tokens and force re-login
        if (responseCode == 401) {
            _authManager.clearTokens();
        }

        if (callback != null) {
            callback.invoke(null);
        }
    }

    /**
     * Parse a DeviceRideDto with its entries.
     */
    private function parseRideDto(raw as Lang.Dictionary) as Lang.Dictionary {
        var rideStart = raw.get("startDateTime");
        var entries = [];
        var rawEntries = raw.get("entries");
        if (rawEntries != null && rawEntries instanceof Lang.Array) {
            for (var i = 0; i < rawEntries.size(); i++) {
                var rawEntry = rawEntries[i];
                if (rawEntry instanceof Lang.Dictionary) {
                    var entryDict = rawEntry as Lang.Dictionary;
                    // Each entry (one group) carries its group's start, absent from an
                    // older backend: fall back on the ride's (docs/LEDGER_*.md API-84).
                    var entryStart = entryDict.get("startDateTime");
                    entries.add({
                        "startDateTime" => entryStart != null ? entryStart : rideStart,
                        "routeSlug" => entryDict.get("routeSlug"),
                        "routeName" => entryDict.get("routeName"),
                        "groupName" => entryDict.get("groupName"),
                        "distance" => entryDict.get("distance"),
                        "elevationGain" => entryDict.get("elevationGain"),
                        "startLat" => entryDict.get("startLat"),
                        "startLon" => entryDict.get("startLon"),
                    });
                }
            }
        }
        return {
            "teamSlug" => raw.get("teamSlug"),
            "rideSlug" => raw.get("rideSlug"),
            "rideName" => raw.get("rideName"),
            "startDateTime" => rideStart,
            "entries" => entries,
        };
    }

    /**
     * Parse a standalone DeviceRouteDto.
     */
    private function parseStandaloneRouteDto(raw as Lang.Dictionary) as Lang.Dictionary {
        return {
            "teamSlug" => raw.get("teamSlug"),
            "routeSlug" => raw.get("routeSlug"),
            "routeName" => raw.get("routeName"),
            "distance" => raw.get("distance"),
            "elevationGain" => raw.get("elevationGain"),
            "startLat" => raw.get("startLat"),
            "startLon" => raw.get("startLon"),
        };
    }

    /**
     * Parse a DeviceRegisteredGroupDto, keeping only what the list and the download need.
     * Of its syncStatuses only the GARMIN entry's state is kept (docs/LEDGER_*.md API-121).
     */
    private function parseRegisteredGroupDto(raw as Lang.Dictionary) as Lang.Dictionary {
        return {
            "teamSlug" => raw.get("teamSlug"),
            "routeSlug" => raw.get("routeSlug"),
            "routeName" => raw.get("routeName"),
            "rideName" => raw.get("rideName"),
            "groupName" => raw.get("groupName"),
            "startDateTime" => raw.get("startDateTime"),
            "distance" => raw.get("distance"),
            "elevationGain" => raw.get("elevationGain"),
            "syncState" => parseGarminSyncState(raw.get("syncStatuses")),
        };
    }

    /**
     * The GARMIN state among a group's syncStatuses (SENT, OUTDATED, PENDING, FAILING, RECONNECT_REQUIRED),
     * or null when Garmin does not hold the route or the field is absent (older backend: unknown,
     * not "not sent" — nothing is shown either way).
     */
    private function parseGarminSyncState(rawStatuses) {
        if (rawStatuses == null || !(rawStatuses instanceof Lang.Array)) {
            return null;
        }
        for (var i = 0; i < rawStatuses.size(); i++) {
            var status = rawStatuses[i];
            if (status instanceof Lang.Dictionary) {
                var serviceType = (status as Lang.Dictionary).get("serviceType");
                if (serviceType != null && serviceType.equals("GARMIN")) {
                    return (status as Lang.Dictionary).get("state");
                }
            }
        }
        return null;
    }

    /**
     * Download FIT file for a route.
     *
     * Only one download at a time: the callback is a single field, so a second download would take
     * over the first one's callback and leave its caller waiting forever. A download started while
     * another is in flight (its progress screen closed, say) is refused.
     *
     * @return false, without calling back, when another download is still in progress
     */
    function downloadRoute(teamSlug, routeSlug, callback) as Lang.Boolean {
        if (_downloadCallback != null) {
            return false;
        }
        _downloadCallback = callback;

        // Check if we need to refresh token first
        if (_authManager.needsRefresh()) {
            // Store params for after refresh
            _pendingDownload = [teamSlug, routeSlug];
            refreshToken(method(:onRefreshForDownload));
            return true;
        }

        doDownloadRoute(teamSlug, routeSlug);
        return true;
    }

    /**
     * Callback after refreshing token for download.
     */
    function onRefreshForDownload(success) as Void {
        if (success && _pendingDownload != null) {
            doDownloadRoute(_pendingDownload[0], _pendingDownload[1]);
        } else {
            var callback = _downloadCallback;
            _downloadCallback = null;
            _pendingDownload = null;
            if (callback != null) {
                callback.invoke(false);
            }
        }
    }

    /**
     * Actually download the FIT file.
     */
    private function doDownloadRoute(teamSlug, routeSlug) as Void {
        _pendingDownload = null;

        var url = API_BASE_URL + "/device/routes/" + teamSlug + "/" + routeSlug + "/fit";
        var accessToken = _authManager.getAccessToken();

        // Use download to file for FIT files
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "Authorization" => "Bearer " + accessToken,
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_FIT,
        };

        Communications.makeWebRequest(url, null, options, method(:onDownloadResponse));
    }

    /**
     * Handle FIT download response.
     */
    function onDownloadResponse(
        responseCode as Lang.Number,
        data as Lang.Dictionary or Lang.String or Null
    ) as Void {
        var callback = _downloadCallback;
        _downloadCallback = null;

        if (responseCode == 200) {
            if (callback != null) {
                callback.invoke(true);
            }
            return;
        }

        // If 401, clear tokens
        if (responseCode == 401) {
            _authManager.clearTokens();
        }

        if (callback != null) {
            callback.invoke(false);
        }
    }
}
