// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/accept_invitation_request.dart';
import '../models/invitation_preview_dto.dart';
import '../models/member_dto.dart';
import '../models/my_invitation_list_response.dart';

part 'invitations_client.g.dart';

@RestApi()
abstract class InvitationsClient {
  factory InvitationsClient(Dio dio, {String? baseUrl}) = _InvitationsClient;

  /// Accept an invitation.
  ///
  /// Joins the team the token names. Requires a session: accepting is consenting, and a consent attaches to an account — a public accept handing back a session would make the invitation link a login credential. Idempotent: replaying it, or accepting when already a member, returns the existing membership without changing its role, so an invitation as MEMBER never demotes an administrator.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/invitations/accept')
  Future<MemberDto> accept({
    @Body() required AcceptInvitationRequest body,
  });

  /// Read an invitation.
  ///
  /// What the invitation says, for whoever holds its token. Public, because an invitation opened in a signed-out browser has to be able to name the team and the person inviting — otherwise the page can only show a bare login form with no explanation of why. Nothing here goes beyond what the e-mail already said, and the invited address comes back masked.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/invitations/preview')
  Future<InvitationPreviewDto> preview({
    @Body() required AcceptInvitationRequest body,
  });

  /// My pending invitations.
  ///
  /// Live invitations addressed to the current user, newest first. Teams they already belong to are left out.
  @GET('/api/users/me/invitations')
  Future<MyInvitationListResponse> listMyInvitations();

  /// Accept one of my invitations.
  ///
  /// Same effect as redeeming the token, for an invitation reached from this list.
  ///
  /// [invitationId] - Invitation ID (TSID).
  @POST('/api/users/me/invitations/{invitationId}/accept')
  Future<MemberDto> acceptMyInvitation({
    @Path('invitationId') required String invitationId,
  });
}
