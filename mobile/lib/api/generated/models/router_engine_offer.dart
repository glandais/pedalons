// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'router_engine.dart';
import 'router_profile.dart';

part 'router_engine_offer.freezed.dart';
part 'router_engine_offer.g.dart';

@Freezed()
abstract class RouterEngineOffer with _$RouterEngineOffer {
  const factory RouterEngineOffer({
    required RouterEngine engine,
    required List<RouterProfile> profiles,
  }) = _RouterEngineOffer;

  factory RouterEngineOffer.fromJson(Map<String, Object?> json) =>
      _$RouterEngineOfferFromJson(json);
}
