// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'router_engine_offer.dart';

part 'router_engines_response.freezed.dart';
part 'router_engines_response.g.dart';

@Freezed()
abstract class RouterEnginesResponse with _$RouterEnginesResponse {
  const factory RouterEnginesResponse({
    /// The engines the planner can ask for a leg. STADIA is always there, with every profile; PEDALONS only when the service behind it is configured and says it is ready
    required List<RouterEngineOffer> engines,
  }) = _RouterEnginesResponse;

  factory RouterEnginesResponse.fromJson(Map<String, Object?> json) =>
      _$RouterEnginesResponseFromJson(json);
}
