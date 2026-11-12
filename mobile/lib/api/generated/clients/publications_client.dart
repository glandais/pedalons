// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/count_response.dart';
import '../models/list_view_mode.dart';
import '../models/min_role.dart';
import '../models/publication_list_response.dart';
import '../models/publication_type.dart';
import '../models/publication_when.dart';
import '../models/sort_direction.dart';
import '../models/status.dart';

part 'publications_client.g.dart';

@RestApi()
abstract class PublicationsClient {
  factory PublicationsClient(Dio dio, {String? baseUrl}) = _PublicationsClient;

  /// List all publications.
  ///
  /// Get publications from all accessible teams (user's teams + public teams).
  ///
  /// [from] - Start date filter (ISO format).
  ///
  /// [minRole] - Only publications from teams where the user has at least this role. Yields nothing for an anonymous visitor.
  ///
  /// [page] - Page number.
  ///
  /// [participating] - Only publications the current user is registered to (rides and trips). Yields nothing for an anonymous visitor.
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [size] - Page size.
  ///
  /// [sortDir] - Order of the publication date. Omitted, or DESC, is newest first (the feed); ASC is soonest first — what a window of upcoming outings needs, so a page keeps the nearest ones. Given, it overrides the order set by when, except with when=UPCOMING_FIRST, which ignores it.
  ///
  /// [status] - Only publications with this status. Narrows the visibility rules, never widens them.
  ///
  /// [to] - End date filter (ISO format).
  ///
  /// [type] - Types.
  ///
  /// [view] - How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte.
  ///
  /// [when] - Which side of now, judged by the end of a ride or a trip rather than its start: UPCOMING is what is not over yet (end >= now — an outing under way included), PAST what is over (end < now). Keeps rides and trips only: a post has no end. Sets the order too — UPCOMING soonest departure first, PAST latest first — unless sortDir is given. With participating=true, UPCOMING is « Je participe ». UPCOMING_FIRST filters nothing and orders the list in two sections (rule RL15): first what UPCOMING keeps, soonest departure first, then everything else — the rides and trips over and the posts — latest first; the id ends each section's key, so the order is total. The listing then fills upcomingTotal, the size of the first section; sortDir is ignored. On a count endpoint UPCOMING_FIRST counts the whole list, as omitting when does. Omitted: no such filter, newest first.
  @GET('/api/publications')
  Future<PublicationListResponse> listAllPublications({
    @Query('page') int? page = 0,
    @Query('participating') bool? participating = false,
    @Query('size') int? size = 20,
    @Query('from') String? from,
    @Query('minRole') MinRole? minRole,
    @Query('search') String? search,
    @Query('sortDir') SortDirection? sortDir,
    @Query('status') Status? status,
    @Query('to') String? to,
    @Query('type') PublicationType? type,
    @Query('view') ListViewMode? view,
    @Query('when') PublicationWhen? whenField,
  });

  /// Count all publications.
  ///
  /// How many publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
  ///
  /// [from] - Start date filter (ISO format).
  ///
  /// [minRole] - Only publications from teams where the user has at least this role. Yields zero for an anonymous visitor.
  ///
  /// [participating] - Only publications the current user is registered to (rides and trips). Yields zero for an anonymous visitor.
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [status] - Only publications with this status. Narrows the visibility rules, never widens them.
  ///
  /// [to] - End date filter (ISO format).
  ///
  /// [type] - Types.
  ///
  /// [when] - Which side of now, judged by the end of a ride or a trip rather than its start: UPCOMING is what is not over yet (end >= now — an outing under way included), PAST what is over (end < now). Keeps rides and trips only: a post has no end. Sets the order too — UPCOMING soonest departure first, PAST latest first — unless sortDir is given. With participating=true, UPCOMING is « Je participe ». UPCOMING_FIRST filters nothing and orders the list in two sections (rule RL15): first what UPCOMING keeps, soonest departure first, then everything else — the rides and trips over and the posts — latest first; the id ends each section's key, so the order is total. The listing then fills upcomingTotal, the size of the first section; sortDir is ignored. On a count endpoint UPCOMING_FIRST counts the whole list, as omitting when does. Omitted: no such filter, newest first.
  @GET('/api/publications/count')
  Future<CountResponse> countAllPublications({
    @Query('participating') bool? participating = false,
    @Query('from') String? from,
    @Query('minRole') MinRole? minRole,
    @Query('search') String? search,
    @Query('status') Status? status,
    @Query('to') String? to,
    @Query('type') PublicationType? type,
    @Query('when') PublicationWhen? whenField,
  });

  /// List publications.
  ///
  /// Get paginated list of publications for a team with optional filtering.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [from] - Start date filter (ISO format).
  ///
  /// [page] - Page number.
  ///
  /// [participating] - Only publications the current user is registered to (rides and trips). Yields nothing for an anonymous visitor.
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [size] - Page size.
  ///
  /// [sortDir] - Order of the publication date. Omitted, or DESC, is newest first (the feed); ASC is soonest first — what a window of upcoming outings needs, so a page keeps the nearest ones. Given, it overrides the order set by when, except with when=UPCOMING_FIRST, which ignores it.
  ///
  /// [status] - Only publications with this status. Narrows the visibility rules, never widens them.
  ///
  /// [tags] - Only the publications carrying at least one of these tags — ids (TSID) of the team's tags of kind 'type', comma-separated or repeated. Honoured with a 'type' only: the mixed feed has no tag filter and ignores it. Unknown ids are ignored; a filter left with no known id filters nothing.
  ///
  /// [to] - End date filter (ISO format).
  ///
  /// [type] - Type.
  ///
  /// [view] - How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte.
  ///
  /// [when] - Which side of now, judged by the end of a ride or a trip rather than its start: UPCOMING is what is not over yet (end >= now — an outing under way included), PAST what is over (end < now). Keeps rides and trips only: a post has no end. Sets the order too — UPCOMING soonest departure first, PAST latest first — unless sortDir is given. With participating=true, UPCOMING is « Je participe ». UPCOMING_FIRST filters nothing and orders the list in two sections (rule RL15): first what UPCOMING keeps, soonest departure first, then everything else — the rides and trips over and the posts — latest first; the id ends each section's key, so the order is total. The listing then fills upcomingTotal, the size of the first section; sortDir is ignored. On a count endpoint UPCOMING_FIRST counts the whole list, as omitting when does. Omitted: no such filter, newest first.
  ///
  /// [withFullGroup] - Only the rides with at least one group at capacity (maxParticipants reached). Every other type of publication is left out.
  ///
  /// [withoutRoute] - Only the rides routed nowhere: neither the ride nor any of its groups has a route. Every other type of publication is left out.
  @GET('/api/teams/{teamSlug}/publications')
  Future<PublicationListResponse> listPublications({
    @Path('teamSlug') required String teamSlug,
    @Query('page') int? page = 0,
    @Query('participating') bool? participating = false,
    @Query('size') int? size = 20,
    @Query('withFullGroup') bool? withFullGroup = false,
    @Query('withoutRoute') bool? withoutRoute = false,
    @Query('from') String? from,
    @Query('search') String? search,
    @Query('sortDir') SortDirection? sortDir,
    @Query('status') Status? status,
    @Query('tags') List<String>? tags,
    @Query('to') String? to,
    @Query('type') PublicationType? type,
    @Query('view') ListViewMode? view,
    @Query('when') PublicationWhen? whenField,
  });

  /// Count publications.
  ///
  /// How many of the team's publications match the filters, with none of them read. Accepts exactly the same filters as the listing, minus pagination, so a count and the list it opens can never disagree.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [from] - Start date filter (ISO format).
  ///
  /// [participating] - Only publications the current user is registered to (rides and trips). Yields zero for an anonymous visitor.
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [status] - Only publications with this status. Narrows the visibility rules, never widens them.
  ///
  /// [tags] - Only the publications carrying at least one of these tags — ids (TSID) of the team's tags of kind 'type', comma-separated or repeated. Honoured with a 'type' only: the mixed feed has no tag filter and ignores it. Unknown ids are ignored; a filter left with no known id filters nothing.
  ///
  /// [to] - End date filter (ISO format).
  ///
  /// [type] - Type.
  ///
  /// [when] - Which side of now, judged by the end of a ride or a trip rather than its start: UPCOMING is what is not over yet (end >= now — an outing under way included), PAST what is over (end < now). Keeps rides and trips only: a post has no end. Sets the order too — UPCOMING soonest departure first, PAST latest first — unless sortDir is given. With participating=true, UPCOMING is « Je participe ». UPCOMING_FIRST filters nothing and orders the list in two sections (rule RL15): first what UPCOMING keeps, soonest departure first, then everything else — the rides and trips over and the posts — latest first; the id ends each section's key, so the order is total. The listing then fills upcomingTotal, the size of the first section; sortDir is ignored. On a count endpoint UPCOMING_FIRST counts the whole list, as omitting when does. Omitted: no such filter, newest first.
  ///
  /// [withFullGroup] - Only the rides with at least one group at capacity (maxParticipants reached). Every other type of publication is left out.
  ///
  /// [withoutRoute] - Only the rides routed nowhere: neither the ride nor any of its groups has a route. Every other type of publication is left out.
  @GET('/api/teams/{teamSlug}/publications/count')
  Future<CountResponse> countPublications({
    @Path('teamSlug') required String teamSlug,
    @Query('participating') bool? participating = false,
    @Query('withFullGroup') bool? withFullGroup = false,
    @Query('withoutRoute') bool? withoutRoute = false,
    @Query('from') String? from,
    @Query('search') String? search,
    @Query('status') Status? status,
    @Query('tags') List<String>? tags,
    @Query('to') String? to,
    @Query('type') PublicationType? type,
    @Query('when') PublicationWhen? whenField,
  });
}
