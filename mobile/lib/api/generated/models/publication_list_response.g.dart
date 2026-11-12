// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publication_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicationListResponse _$PublicationListResponseFromJson(
  Map<String, dynamic> json,
) => _PublicationListResponse(
  publications: (json['publications'] as List<dynamic>)
      .map((e) => PublicationDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  page: (json['page'] as num).toInt(),
  size: (json['size'] as num).toInt(),
  upcomingTotal: (json['upcomingTotal'] as num?)?.toInt(),
);

Map<String, dynamic> _$PublicationListResponseToJson(
  _PublicationListResponse instance,
) => <String, dynamic>{
  'publications': instance.publications.map((e) => e.toJson()).toList(),
  'total': instance.total,
  'page': instance.page,
  'size': instance.size,
  'upcomingTotal': instance.upcomingTotal,
};
