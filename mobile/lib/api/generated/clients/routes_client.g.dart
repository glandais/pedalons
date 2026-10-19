// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _RoutesClient implements RoutesClient {
  _RoutesClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<RouteListResponse> listAllRoutes({
    int? page = 0,
    int? size = 20,
    Hilliness? hilliness,
    double? maxDistance,
    double? maxElevationGain,
    double? minDistance,
    double? minElevationGain,
    MinRole? minRole,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    NearType? nearType,
    String? search,
    RouteSortBy? sortBy,
    SortDirection? sortDir,
    SurfaceType? surfaceType,
    ListViewMode? view,
    WindDirection? windDirection,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'page': page,
      r'size': size,
      r'hilliness': hilliness?.toJson(),
      r'maxDistance': maxDistance,
      r'maxElevationGain': maxElevationGain,
      r'minDistance': minDistance,
      r'minElevationGain': minElevationGain,
      r'minRole': minRole?.toJson(),
      r'nearLat': nearLat,
      r'nearLon': nearLon,
      r'nearRadius': nearRadius,
      r'nearType': nearType?.toJson(),
      r'search': search,
      r'sortBy': sortBy?.toJson(),
      r'sortDir': sortDir?.toJson(),
      r'surfaceType': surfaceType?.toJson(),
      r'view': view?.toJson(),
      r'windDirection': windDirection?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<RouteListResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/routes',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteListResponse _value;
    try {
      _value = RouteListResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RouteBoundsResponse> getAllRoutesBounds({
    Hilliness? hilliness,
    double? maxDistance,
    double? maxElevationGain,
    double? minDistance,
    double? minElevationGain,
    MinRole? minRole,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    NearType? nearType,
    String? search,
    SurfaceType? surfaceType,
    WindDirection? windDirection,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'hilliness': hilliness?.toJson(),
      r'maxDistance': maxDistance,
      r'maxElevationGain': maxElevationGain,
      r'minDistance': minDistance,
      r'minElevationGain': minElevationGain,
      r'minRole': minRole?.toJson(),
      r'nearLat': nearLat,
      r'nearLon': nearLon,
      r'nearRadius': nearRadius,
      r'nearType': nearType?.toJson(),
      r'search': search,
      r'surfaceType': surfaceType?.toJson(),
      r'windDirection': windDirection?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<RouteBoundsResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/routes/bounds',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteBoundsResponse _value;
    try {
      _value = RouteBoundsResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<CountResponse> countAllRoutes({
    Hilliness? hilliness,
    double? maxDistance,
    double? maxElevationGain,
    double? minDistance,
    double? minElevationGain,
    MinRole? minRole,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    NearType? nearType,
    String? search,
    SurfaceType? surfaceType,
    WindDirection? windDirection,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'hilliness': hilliness?.toJson(),
      r'maxDistance': maxDistance,
      r'maxElevationGain': maxElevationGain,
      r'minDistance': minDistance,
      r'minElevationGain': minElevationGain,
      r'minRole': minRole?.toJson(),
      r'nearLat': nearLat,
      r'nearLon': nearLon,
      r'nearRadius': nearRadius,
      r'nearType': nearType?.toJson(),
      r'search': search,
      r'surfaceType': surfaceType?.toJson(),
      r'windDirection': windDirection?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<CountResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/routes/count',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late CountResponse _value;
    try {
      _value = CountResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<void> allRoutesTile({
    required int x,
    required int y,
    required int z,
    Hilliness? hilliness,
    double? maxDistance,
    double? maxElevationGain,
    double? minDistance,
    double? minElevationGain,
    MinRole? minRole,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    NearType? nearType,
    String? search,
    SurfaceType? surfaceType,
    String? t,
    WindDirection? windDirection,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'hilliness': hilliness?.toJson(),
      r'maxDistance': maxDistance,
      r'maxElevationGain': maxElevationGain,
      r'minDistance': minDistance,
      r'minElevationGain': minElevationGain,
      r'minRole': minRole?.toJson(),
      r'nearLat': nearLat,
      r'nearLon': nearLon,
      r'nearRadius': nearRadius,
      r'nearType': nearType?.toJson(),
      r'search': search,
      r'surfaceType': surfaceType?.toJson(),
      r't': t,
      r'windDirection': windDirection?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<void>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/routes/tiles/${z}/${x}/${y}.mvt',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    await _dio.fetch<void>(_options);
  }

  @override
  Future<RouteListResponse> listRoutes({
    required String teamSlug,
    int? page = 0,
    int? size = 20,
    Hilliness? hilliness,
    double? maxDistance,
    double? maxElevationGain,
    double? minDistance,
    double? minElevationGain,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    NearType? nearType,
    String? search,
    RouteSortBy? sortBy,
    SortDirection? sortDir,
    SurfaceType? surfaceType,
    List<String>? tags,
    ListViewMode? view,
    WindDirection? windDirection,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'page': page,
      r'size': size,
      r'hilliness': hilliness?.toJson(),
      r'maxDistance': maxDistance,
      r'maxElevationGain': maxElevationGain,
      r'minDistance': minDistance,
      r'minElevationGain': minElevationGain,
      r'nearLat': nearLat,
      r'nearLon': nearLon,
      r'nearRadius': nearRadius,
      r'nearType': nearType?.toJson(),
      r'search': search,
      r'sortBy': sortBy?.toJson(),
      r'sortDir': sortDir?.toJson(),
      r'surfaceType': surfaceType?.toJson(),
      r'tags': tags,
      r'view': view?.toJson(),
      r'windDirection': windDirection?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<RouteListResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteListResponse _value;
    try {
      _value = RouteListResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RouteDto> createRoute({
    required String teamSlug,
    RouteRequest? route,
    MultipartFile? gpxFile,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    final _data = FormData();
    _data.fields.add(
      MapEntry('route', jsonEncode(route ?? <String, dynamic>{})),
    );
    if (gpxFile != null) {
      _data.files.add(MapEntry('gpxFile', gpxFile));
    }
    final _options = _setStreamType<RouteDto>(
      Options(
            method: 'POST',
            headers: _headers,
            extra: _extra,
            contentType: 'multipart/form-data',
          )
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteDto _value;
    try {
      _value = RouteDto.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RouteBoundsResponse> getRoutesBounds({
    required String teamSlug,
    Hilliness? hilliness,
    double? maxDistance,
    double? maxElevationGain,
    double? minDistance,
    double? minElevationGain,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    NearType? nearType,
    String? search,
    SurfaceType? surfaceType,
    List<String>? tags,
    WindDirection? windDirection,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'hilliness': hilliness?.toJson(),
      r'maxDistance': maxDistance,
      r'maxElevationGain': maxElevationGain,
      r'minDistance': minDistance,
      r'minElevationGain': minElevationGain,
      r'nearLat': nearLat,
      r'nearLon': nearLon,
      r'nearRadius': nearRadius,
      r'nearType': nearType?.toJson(),
      r'search': search,
      r'surfaceType': surfaceType?.toJson(),
      r'tags': tags,
      r'windDirection': windDirection?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<RouteBoundsResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/bounds',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteBoundsResponse _value;
    try {
      _value = RouteBoundsResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RoutesBulkResponse> getRoutesBulk({
    required String teamSlug,
    List<String>? slug,
    bool? geometry = true,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'slug': slug,
      r'geometry': geometry,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<RoutesBulkResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/bulk',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RoutesBulkResponse _value;
    try {
      _value = RoutesBulkResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<CountResponse> countRoutes({
    required String teamSlug,
    Hilliness? hilliness,
    double? maxDistance,
    double? maxElevationGain,
    double? minDistance,
    double? minElevationGain,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    NearType? nearType,
    String? search,
    SurfaceType? surfaceType,
    List<String>? tags,
    WindDirection? windDirection,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'hilliness': hilliness?.toJson(),
      r'maxDistance': maxDistance,
      r'maxElevationGain': maxElevationGain,
      r'minDistance': minDistance,
      r'minElevationGain': minElevationGain,
      r'nearLat': nearLat,
      r'nearLon': nearLon,
      r'nearRadius': nearRadius,
      r'nearType': nearType?.toJson(),
      r'search': search,
      r'surfaceType': surfaceType?.toJson(),
      r'tags': tags,
      r'windDirection': windDirection?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<CountResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/count',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late CountResponse _value;
    try {
      _value = CountResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<void> routesTile({
    required String teamSlug,
    required int x,
    required int y,
    required int z,
    Hilliness? hilliness,
    double? maxDistance,
    double? maxElevationGain,
    double? minDistance,
    double? minElevationGain,
    double? nearLat,
    double? nearLon,
    double? nearRadius,
    NearType? nearType,
    String? search,
    SurfaceType? surfaceType,
    String? t,
    List<String>? tags,
    WindDirection? windDirection,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'hilliness': hilliness?.toJson(),
      r'maxDistance': maxDistance,
      r'maxElevationGain': maxElevationGain,
      r'minDistance': minDistance,
      r'minElevationGain': minElevationGain,
      r'nearLat': nearLat,
      r'nearLon': nearLon,
      r'nearRadius': nearRadius,
      r'nearType': nearType?.toJson(),
      r'search': search,
      r'surfaceType': surfaceType?.toJson(),
      r't': t,
      r'tags': tags,
      r'windDirection': windDirection?.toJson(),
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<void>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/tiles/${z}/${x}/${y}.mvt',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    await _dio.fetch<void>(_options);
  }

  @override
  Future<RouteDto> updateRoute({
    required String routeSlug,
    required String teamSlug,
    RouteRequest? route,
    MultipartFile? gpxFile,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    final _data = FormData();
    _data.fields.add(
      MapEntry('route', jsonEncode(route ?? <String, dynamic>{})),
    );
    if (gpxFile != null) {
      _data.files.add(MapEntry('gpxFile', gpxFile));
    }
    final _options = _setStreamType<RouteDto>(
      Options(
            method: 'PUT',
            headers: _headers,
            extra: _extra,
            contentType: 'multipart/form-data',
          )
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/${routeSlug}',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteDto _value;
    try {
      _value = RouteDto.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RouteDetailDto> getRoute({
    required String routeSlug,
    required String teamSlug,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<RouteDetailDto>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/${routeSlug}',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteDetailDto _value;
    try {
      _value = RouteDetailDto.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<void> deleteRoute({
    required String routeSlug,
    required String teamSlug,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<void>(
      Options(method: 'DELETE', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/${routeSlug}',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    await _dio.fetch<void>(_options);
  }

  @override
  Future<PlannerStateResponse> getRoutePlannerState({
    required String routeSlug,
    required String teamSlug,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<PlannerStateResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/${routeSlug}/planner-state',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PlannerStateResponse _value;
    try {
      _value = PlannerStateResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RouteDetailDto> changeRouteSlug({
    required String routeSlug,
    required String teamSlug,
    required SlugChangeRequest body,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    final _data = <String, dynamic>{};
    _data.addAll(body.toJson());
    final _options = _setStreamType<RouteDetailDto>(
      Options(method: 'PATCH', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/${routeSlug}/slug',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteDetailDto _value;
    try {
      _value = RouteDetailDto.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RouteDetailDto> undeleteRoute({
    required String routeSlug,
    required String teamSlug,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<RouteDetailDto>(
      Options(method: 'POST', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/${routeSlug}/undelete',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteDetailDto _value;
    try {
      _value = RouteDetailDto.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<RouteUsagesResponse> getRouteUsages({
    required String routeSlug,
    required String teamSlug,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{};
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<RouteUsagesResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/routes/${routeSlug}/usages',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late RouteUsagesResponse _value;
    try {
      _value = RouteUsagesResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  RequestOptions _setStreamType<T>(RequestOptions requestOptions) {
    if (T != dynamic &&
        !(requestOptions.responseType == ResponseType.bytes ||
            requestOptions.responseType == ResponseType.stream)) {
      if (T == String) {
        requestOptions.responseType = ResponseType.plain;
      } else {
        requestOptions.responseType = ResponseType.json;
      }
    }
    return requestOptions;
  }

  String _combineBaseUrls(String dioBaseUrl, String? baseUrl) {
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      return dioBaseUrl;
    }

    final url = Uri.parse(baseUrl);

    if (url.isAbsolute) {
      return url.toString();
    }

    return Uri.parse(dioBaseUrl).resolveUri(url).toString();
  }
}

// dart format on
