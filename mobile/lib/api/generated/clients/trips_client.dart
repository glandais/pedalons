// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/participant_list_response.dart';
import '../models/slug_change_request.dart';
import '../models/status_change_request.dart';
import '../models/trip_dto.dart';
import '../models/trip_participation_dto.dart';
import '../models/trip_request.dart';
import '../models/trip_weather_dto.dart';

part 'trips_client.g.dart';

@RestApi()
abstract class TripsClient {
  factory TripsClient(Dio dio, {String? baseUrl}) = _TripsClient;

  /// Create trip.
  ///
  /// Create a new trip with optional stages.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/teams/{teamSlug}/trips')
  Future<TripDto> createTrip({
    @Path('teamSlug') required String teamSlug,
    @Body() required TripRequest body,
  });

  /// Update trip.
  ///
  /// Update trip information. Requires organizer permissions.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/teams/{teamSlug}/trips/{tripSlug}')
  Future<TripDto> updateTrip({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
    @Body() required TripRequest body,
  });

  /// Get trip details.
  ///
  /// Get detailed trip information including stages and participants.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  @GET('/api/teams/{teamSlug}/trips/{tripSlug}')
  Future<TripDto> getTrip({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
  });

  /// Delete trip.
  ///
  /// Soft delete a trip. Requires organizer permissions.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  @DELETE('/api/teams/{teamSlug}/trips/{tripSlug}')
  Future<void> deleteTrip({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
  });

  /// Download trip as a calendar file.
  ///
  /// One all-day VEVENT per stage, to add the trip on its own to a calendar. Readable by whoever may read the trip; no calendar token.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  @GET('/api/teams/{teamSlug}/trips/{tripSlug}/ics')
  Future<String> downloadTripIcs({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
  });

  /// Join trip.
  ///
  /// Join a trip as a participant.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  @POST('/api/teams/{teamSlug}/trips/{tripSlug}/join')
  Future<TripParticipationDto> joinTrip({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
  });

  /// Leave trip.
  ///
  /// Leave a trip as a participant.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  @POST('/api/teams/{teamSlug}/trips/{tripSlug}/leave')
  Future<void> leaveTrip({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
  });

  /// List trip participants.
  ///
  /// One page of the people registered to the trip, earliest registrations first, searchable by display name. The trip detail only embeds the first few; this is the whole list, with its total. Members of the team only (and platform administrators): member names are never sent to anyone else.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  ///
  /// [page] - Page number (0-based).
  ///
  /// [search] - Search by display name.
  ///
  /// [size] - Page size.
  @GET('/api/teams/{teamSlug}/trips/{tripSlug}/participants')
  Future<ParticipantListResponse> getTripParticipants({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
    @Query('search') String? search,
    @Query('page') int? page = 0,
    @Query('size') int? size = 50,
  });

  /// Change trip slug.
  ///
  /// Change trip URL slug. Requires organizer permissions.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Current trip URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PATCH('/api/teams/{teamSlug}/trips/{tripSlug}/slug')
  Future<TripDto> changeTripSlug({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
    @Body() required SlugChangeRequest body,
  });

  /// Change trip status.
  ///
  /// Change the trip's status and nothing else — what a list row can do without the full trip. Same side effects as a status change through the update. Requires organizer permissions. The stages follow the trip.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PATCH('/api/teams/{teamSlug}/trips/{tripSlug}/status')
  Future<TripDto> changeTripStatus({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
    @Body() required StatusChangeRequest body,
  });

  /// Restore trip.
  ///
  /// Restore a soft-deleted trip. Requires organizer permissions.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  @POST('/api/teams/{teamSlug}/trips/{tripSlug}/undelete')
  Future<TripDto> undeleteTrip({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
  });

  /// Get trip weather.
  ///
  /// The forecast for the trip, stage by stage: along each stage's route at its estimated passages (stage speed, else 25 km/h), each stage with its own state. Read from the server's cache only — the forecast is refreshed in the background, never on request. Readable by whoever may read the trip, and then always 200: the state is in status. Cache-Control: private, no-cache with an ETag (revalidate with If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [tripSlug] - Trip URL slug.
  @GET('/api/teams/{teamSlug}/trips/{tripSlug}/weather')
  Future<TripWeatherDto> getTripWeather({
    @Path('teamSlug') required String teamSlug,
    @Path('tripSlug') required String tripSlug,
  });
}
