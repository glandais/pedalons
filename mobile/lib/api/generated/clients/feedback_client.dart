// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/error_report_request.dart';
import '../models/feedback_request.dart';

part 'feedback_client.g.dart';

@RestApi()
abstract class FeedbackClient {
  factory FeedbackClient(Dio dio, {String? baseUrl}) = _FeedbackClient;

  /// Report a bug or suggest something.
  ///
  /// Files the member's report with the technical context their client attached. It reaches the maintainers as an issue of a private repository, naming the member by id only; tokens and e-mail addresses are redacted from the context and the log.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/feedback')
  Future<void> sendFeedback({
    @Body() required FeedbackRequest body,
  });

  /// Report an unhandled error.
  ///
  /// Sent by a client, without the member's intervention, when it catches an unhandled error. The same error reported by many clients becomes one issue. Always 204 once valid, including past the per-member quota, where it is dropped: a client must never retry nor surface this call's failure.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/feedback/errors')
  Future<void> reportClientError({
    @Body() required ErrorReportRequest body,
  });
}
