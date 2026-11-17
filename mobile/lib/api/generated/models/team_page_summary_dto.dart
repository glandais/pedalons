// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'status.dart';
import 'visibility.dart';

part 'team_page_summary_dto.freezed.dart';
part 'team_page_summary_dto.g.dart';

/// Team page summary for listings
@Freezed()
abstract class TeamPageSummaryDto with _$TeamPageSummaryDto {
  const factory TeamPageSummaryDto({
    /// Page ID (TSID)
    required String id,

    /// Page title
    required String title,

    /// Page URL slug
    required String slug,

    /// Visibility level
    required String visibility,

    /// Page order
    required int order,

    /// Whether the page is soft-deleted
    required bool deleted,

    /// Publication status: a DRAFT is listed only to the team's administrators and the platform admin, who are told it is one (docs/LEDGER_*.md WEB-120)
    required String status,

    /// Hidden by moderation: listed only to the team's organisers, administrators and the platform admin (docs/LEDGER_*.md WEB-120)
    required bool moderationHidden,
  }) = _TeamPageSummaryDto;

  factory TeamPageSummaryDto.fromJson(Map<String, Object?> json) =>
      _$TeamPageSummaryDtoFromJson(json);
}
