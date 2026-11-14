// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'o_auth_error_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OAuthErrorResponse _$OAuthErrorResponseFromJson(Map<String, dynamic> json) =>
    _OAuthErrorResponse(
      error: json['error'] as String,
      errorDescription: json['error_description'] as String,
    );

Map<String, dynamic> _$OAuthErrorResponseToJson(_OAuthErrorResponse instance) =>
    <String, dynamic>{
      'error': instance.error,
      'error_description': instance.errorDescription,
    };
