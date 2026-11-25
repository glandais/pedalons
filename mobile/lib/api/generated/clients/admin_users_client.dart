// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/admin_user_dto.dart';
import '../models/admin_user_list_response.dart';
import '../models/assign_platform_role_request.dart';

part 'admin_users_client.g.dart';

@RestApi()
abstract class AdminUsersClient {
  factory AdminUsersClient(Dio dio, {String? baseUrl}) = _AdminUsersClient;

  /// List all users.
  ///
  /// Get a paginated list of all users.
  ///
  /// [adminOnly] - Show only platform admins.
  ///
  /// [domainId] - Filter by domain ID.
  ///
  /// [page] - Page number (0-indexed).
  ///
  /// [search] - Search by email or name.
  ///
  /// [size] - Page size.
  @GET('/api/admin/users')
  Future<AdminUserListResponse> listUsers({
    @Query('page') int? page = 0,
    @Query('size') int? size = 20,
    @Query('adminOnly') bool? adminOnly,
    @Query('domainId') String? domainId,
    @Query('search') String? search,
  });

  /// Get user details.
  ///
  /// Get detailed user information.
  ///
  /// [userId] - User ID.
  @GET('/api/admin/users/{userId}')
  Future<AdminUserDto> getAdminUser({
    @Path('userId') required String userId,
  });

  /// Assign platform role.
  ///
  /// Assign or remove a platform role from a user.
  ///
  /// [userId] - User ID.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/admin/users/{userId}/platform-role')
  Future<AdminUserDto> assignPlatformRole({
    @Path('userId') required String userId,
    @Body() required AssignPlatformRoleRequest body,
  });
}
