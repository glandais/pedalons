// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publications_client.dart';

// dart format off

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

// ignore_for_file: type=lint
// ignore_for_file: unnecessary_brace_in_string_interps,no_leading_underscores_for_local_identifiers,unused_element,unnecessary_string_interpolations,unused_element_parameter,avoid_unused_constructor_parameters,unreachable_from_main,avoid_redundant_argument_values

class _PublicationsClient implements PublicationsClient {
  _PublicationsClient(this._dio, {this.baseUrl, this.errorLogger});

  final Dio _dio;

  String? baseUrl;

  final ParseErrorLogger? errorLogger;

  @override
  Future<PublicationListResponse> listAllPublications({
    String? from,
    MinRole? minRole,
    String? search,
    SortDirection? sortDir,
    Status? status,
    String? to,
    PublicationType? type,
    ListViewMode? view,
    PublicationWhen? whenField,
    bool? dated = false,
    int? page = 0,
    bool? participating = false,
    int? size = 20,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'from': from,
      r'minRole': minRole?.toJson(),
      r'search': search,
      r'sortDir': sortDir?.toJson(),
      r'status': status?.toJson(),
      r'to': to,
      r'type': type?.toJson(),
      r'view': view?.toJson(),
      r'when': whenField?.toJson(),
      r'dated': dated,
      r'page': page,
      r'participating': participating,
      r'size': size,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<PublicationListResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/publications',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PublicationListResponse _value;
    try {
      _value = PublicationListResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<CountResponse> countAllPublications({
    String? from,
    MinRole? minRole,
    String? search,
    Status? status,
    String? to,
    PublicationType? type,
    PublicationWhen? whenField,
    bool? dated = false,
    bool? participating = false,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'from': from,
      r'minRole': minRole?.toJson(),
      r'search': search,
      r'status': status?.toJson(),
      r'to': to,
      r'type': type?.toJson(),
      r'when': whenField?.toJson(),
      r'dated': dated,
      r'participating': participating,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<CountResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/publications/count',
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
  Future<PublicationListResponse> listPublications({
    required String teamSlug,
    String? from,
    String? search,
    SortDirection? sortDir,
    Status? status,
    List<String>? tags,
    String? to,
    PublicationType? type,
    ListViewMode? view,
    PublicationWhen? whenField,
    bool? dated = false,
    int? page = 0,
    bool? participating = false,
    int? size = 20,
    bool? withFullGroup = false,
    bool? withoutRoute = false,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'from': from,
      r'search': search,
      r'sortDir': sortDir?.toJson(),
      r'status': status?.toJson(),
      r'tags': tags,
      r'to': to,
      r'type': type?.toJson(),
      r'view': view?.toJson(),
      r'when': whenField?.toJson(),
      r'dated': dated,
      r'page': page,
      r'participating': participating,
      r'size': size,
      r'withFullGroup': withFullGroup,
      r'withoutRoute': withoutRoute,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<PublicationListResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/publications',
            queryParameters: queryParameters,
            data: _data,
          )
          .copyWith(baseUrl: _combineBaseUrls(_dio.options.baseUrl, baseUrl)),
    );
    final _result = await _dio.fetch<Map<String, Object?>>(_options);
    late PublicationListResponse _value;
    try {
      _value = PublicationListResponse.fromJson(_result.data!);
    } on Object catch (e, s) {
      errorLogger?.logError(e, s, _options, response: _result);
      rethrow;
    }
    return _value;
  }

  @override
  Future<CountResponse> countPublications({
    required String teamSlug,
    String? from,
    String? search,
    Status? status,
    List<String>? tags,
    String? to,
    PublicationType? type,
    PublicationWhen? whenField,
    bool? dated = false,
    bool? participating = false,
    bool? withFullGroup = false,
    bool? withoutRoute = false,
  }) async {
    final _extra = <String, dynamic>{};
    final queryParameters = <String, dynamic>{
      r'from': from,
      r'search': search,
      r'status': status?.toJson(),
      r'tags': tags,
      r'to': to,
      r'type': type?.toJson(),
      r'when': whenField?.toJson(),
      r'dated': dated,
      r'participating': participating,
      r'withFullGroup': withFullGroup,
      r'withoutRoute': withoutRoute,
    };
    queryParameters.removeWhere((k, v) => v == null);
    final _headers = <String, dynamic>{};
    const Map<String, dynamic>? _data = null;
    final _options = _setStreamType<CountResponse>(
      Options(method: 'GET', headers: _headers, extra: _extra)
          .compose(
            _dio.options,
            '/api/teams/${teamSlug}/publications/count',
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
