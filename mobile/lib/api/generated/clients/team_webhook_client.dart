// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/team_webhook_dto.dart';
import '../models/team_webhook_request.dart';
import '../models/team_webhook_test_dto.dart';

part 'team_webhook_client.g.dart';

@RestApi()
abstract class TeamWebhookClient {
  factory TeamWebhookClient(Dio dio, {String? baseUrl}) = _TeamWebhookClient;

  /// Create or change the team's webhook.
  ///
  /// The message format is read from the URL: Slack, Discord, or a structured JSON document for anything else. Only https URLs to public addresses are accepted. Omitting the URL keeps the current one.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/teams/{teamSlug}/webhook')
  Future<TeamWebhookDto> saveTeamWebhook({
    @Path('teamSlug') required String teamSlug,
    @Body() required TeamWebhookRequest body,
  });

  /// Get the team's webhook.
  ///
  /// The webhook with its URL masked — the URL is a secret. `configured` is false when the team has none.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}/webhook')
  Future<TeamWebhookDto> getTeamWebhook({
    @Path('teamSlug') required String teamSlug,
  });

  /// Remove the team's webhook.
  ///
  /// [teamSlug] - Team URL slug.
  @DELETE('/api/teams/{teamSlug}/webhook')
  Future<void> deleteTeamWebhook({
    @Path('teamSlug') required String teamSlug,
  });

  /// Send a test message to the team's webhook.
  ///
  /// Posts a test message now and reports how the endpoint answered.
  ///
  /// [teamSlug] - Team URL slug.
  @POST('/api/teams/{teamSlug}/webhook/test')
  Future<TeamWebhookTestDto> testTeamWebhook({
    @Path('teamSlug') required String teamSlug,
  });
}
