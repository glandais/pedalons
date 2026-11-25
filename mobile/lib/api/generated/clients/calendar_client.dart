// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/calendar_events_response.dart';
import '../models/calendar_token_dto.dart';

part 'calendar_client.g.dart';

@RestApi()
abstract class CalendarClient {
  factory CalendarClient(Dio dio, {String? baseUrl}) = _CalendarClient;

  /// Get calendar events.
  ///
  /// Get calendar events for all teams the user belongs to.
  ///
  /// [from] - Start date (ISO 8601).
  ///
  /// [to] - End date (ISO 8601).
  @GET('/api/calendar/events')
  Future<CalendarEventsResponse> getEvents({
    @Query('from') String? from,
    @Query('to') String? to,
  });

  /// Get global ICS feed.
  ///
  /// Get ICS calendar feed for all user's teams (requires token).
  ///
  /// [token] - Calendar access token.
  @GET('/api/calendar/ics')
  Future<void> getGlobalIcsFeed({
    @Query('token') String? token,
  });

  /// Get calendar token.
  ///
  /// Get or create the user's calendar token for ICS feed access.
  @GET('/api/calendar/token')
  Future<CalendarTokenDto> getToken();

  /// Regenerate calendar token.
  ///
  /// Regenerate the user's calendar token, invalidating the old one.
  @POST('/api/calendar/token/regenerate')
  Future<CalendarTokenDto> regenerateToken();

  /// Get team calendar events.
  ///
  /// Get calendar events for a specific team.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [from] - Start date (ISO 8601).
  ///
  /// [to] - End date (ISO 8601).
  @GET('/api/teams/{teamSlug}/calendar/events')
  Future<CalendarEventsResponse> getTeamEvents({
    @Path('teamSlug') required String teamSlug,
    @Query('from') String? from,
    @Query('to') String? to,
  });

  /// Get team ICS feed.
  ///
  /// Get ICS calendar feed for a specific team (requires token).
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [token] - Calendar access token.
  @GET('/api/teams/{teamSlug}/calendar/ics')
  Future<void> getTeamIcsFeed({
    @Path('teamSlug') required String teamSlug,
    @Query('token') String? token,
  });
}
