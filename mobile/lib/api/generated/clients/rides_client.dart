// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/participant_list_response.dart';
import '../models/ride_dto.dart';
import '../models/ride_participation_dto.dart';
import '../models/ride_request.dart';
import '../models/ride_weather_dto.dart';
import '../models/slug_change_request.dart';
import '../models/status_change_request.dart';

part 'rides_client.g.dart';

@RestApi()
abstract class RidesClient {
  factory RidesClient(Dio dio, {String? baseUrl}) = _RidesClient;

  /// Create ride.
  ///
  /// Create a new ride with optional groups.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/teams/{teamSlug}/rides')
  Future<RideDto> createRide({
    @Path('teamSlug') required String teamSlug,
    @Body() required RideRequest body,
  });

  /// Update ride.
  ///
  /// Update ride information. Requires organizer permissions.
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/teams/{teamSlug}/rides/{rideSlug}')
  Future<RideDto> updateRide({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
    @Body() required RideRequest body,
  });

  /// Get ride details.
  ///
  /// Get detailed ride information including groups.
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}/rides/{rideSlug}')
  Future<RideDto> getRide({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Delete ride.
  ///
  /// Soft delete a ride. Requires organizer permissions.
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @DELETE('/api/teams/{teamSlug}/rides/{rideSlug}')
  Future<void> deleteRide({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Join ride group.
  ///
  /// Join a ride group.
  ///
  /// [groupId] - Group ID (TSID).
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @POST('/api/teams/{teamSlug}/rides/{rideSlug}/groups/{groupId}/join')
  Future<RideParticipationDto> joinGroup({
    @Path('groupId') required String groupId,
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Leave ride group.
  ///
  /// Leave a ride group.
  ///
  /// [groupId] - Group ID (TSID).
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @POST('/api/teams/{teamSlug}/rides/{rideSlug}/groups/{groupId}/leave')
  Future<void> leaveGroup({
    @Path('groupId') required String groupId,
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Download ride as a calendar file.
  ///
  /// One VEVENT for the ride, to add it on its own to a calendar. Readable by whoever may read the ride; no calendar token.
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}/rides/{rideSlug}/ics')
  Future<String> downloadRideIcs({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// List ride participants.
  ///
  /// One page of the people registered to the ride, or to one of its groups, earliest registrations first, searchable by display name. The ride detail only embeds the first few; this is the whole list, with its total. Members of the team only (and platform administrators): member names are never sent to anyone else.
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [groupId] - Only this group of the ride (TSID); every group when absent.
  ///
  /// [page] - Page number (0-based).
  ///
  /// [search] - Search by display name.
  ///
  /// [size] - Page size.
  @GET('/api/teams/{teamSlug}/rides/{rideSlug}/participants')
  Future<ParticipantListResponse> getRideParticipants({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
    @Query('page') int? page = 0,
    @Query('size') int? size = 50,
    @Query('groupId') String? groupId,
    @Query('search') String? search,
  });

  /// Change ride slug.
  ///
  /// Change ride URL slug. Requires organizer permissions.
  ///
  /// [rideSlug] - Current ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PATCH('/api/teams/{teamSlug}/rides/{rideSlug}/slug')
  Future<RideDto> changeRideSlug({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
    @Body() required SlugChangeRequest body,
  });

  /// Change ride status.
  ///
  /// Change the ride's status and nothing else — what a list row can do without the full ride. Same side effects as a status change through the update. Requires organizer permissions.
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PATCH('/api/teams/{teamSlug}/rides/{rideSlug}/status')
  Future<RideDto> changeRideStatus({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
    @Body() required StatusChangeRequest body,
  });

  /// Restore ride.
  ///
  /// Restore a soft-deleted ride. Requires organizer permissions.
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @POST('/api/teams/{teamSlug}/rides/{rideSlug}/undelete')
  Future<RideDto> undeleteRide({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Get ride weather.
  ///
  /// The forecast for the ride: at the meeting point when it leaves, then along each group's route at its estimated passages (group speed, else 25 km/h). Read from the server's cache only — the forecast is refreshed in the background, never on request. Readable by whoever may read the ride, and then always 200: the state is in status. Cache-Control: private, no-cache with an ETag (revalidate with If-None-Match, 304 when unchanged); no-store when status is UNAVAILABLE.
  ///
  /// [rideSlug] - Ride URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}/rides/{rideSlug}/weather')
  Future<RideWeatherDto> getRideWeather({
    @Path('rideSlug') required String rideSlug,
    @Path('teamSlug') required String teamSlug,
  });
}
