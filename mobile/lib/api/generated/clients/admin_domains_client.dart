// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/admin_activation_response.dart';
import '../models/admin_domain_alias_dto.dart';
import '../models/admin_domain_dto.dart';
import '../models/admin_domain_list_response.dart';
import '../models/admin_gps_credential_dto.dart';
import '../models/admin_stats_dto.dart';
import '../models/create_domain_alias_request.dart';
import '../models/create_domain_request.dart';
import '../models/create_gps_credential_request.dart';
import '../models/update_domain_alias_request.dart';
import '../models/update_domain_request.dart';
import '../models/update_gps_credential_request.dart';

part 'admin_domains_client.g.dart';

@RestApi()
abstract class AdminDomainsClient {
  factory AdminDomainsClient(Dio dio, {String? baseUrl}) = _AdminDomainsClient;

  /// List all domains.
  ///
  /// Get a paginated list of all domains.
  ///
  /// [page] - Page number (0-indexed).
  ///
  /// [size] - Page size.
  @GET('/api/admin/domains')
  Future<AdminDomainListResponse> listDomains({
    @Query('page') int? page = 0,
    @Query('size') int? size = 20,
  });

  /// Create domain.
  ///
  /// Create a new domain.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/admin/domains')
  Future<AdminDomainDto> createDomain({
    @Body() required CreateDomainRequest body,
  });

  /// Activation of new accounts.
  ///
  /// Per sign-up week (ISO week, UTC) and domain: accounts created, verified, that joined a team and that signed up to a ride within 7 days. Counts only, computed on the data already stored — no person is named (ledger API-213).
  ///
  /// [weeks] - Sign-up weeks back, the current one included (1 to 52).
  @GET('/api/admin/domains/activation')
  Future<AdminActivationResponse> getActivation({
    @Query('weeks') int? weeks = 12,
  });

  /// Get platform statistics.
  ///
  /// Get overall platform statistics.
  @GET('/api/admin/domains/stats')
  Future<AdminStatsDto> getStats();

  /// Update domain.
  ///
  /// Update domain information.
  ///
  /// [domainId] - Domain ID.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/admin/domains/{domainId}')
  Future<AdminDomainDto> updateDomain({
    @Path('domainId') required String domainId,
    @Body() required UpdateDomainRequest body,
  });

  /// Get domain details.
  ///
  /// Get detailed domain information.
  ///
  /// [domainId] - Domain ID.
  @GET('/api/admin/domains/{domainId}')
  Future<AdminDomainDto> getDomain({
    @Path('domainId') required String domainId,
  });

  /// List domain aliases.
  ///
  /// Get all dedicated hostnames (aliases) pinned to teams of a domain.
  ///
  /// [domainId] - Domain ID.
  @GET('/api/admin/domains/{domainId}/aliases')
  Future<List<AdminDomainAliasDto>> listDomainAliases({
    @Path('domainId') required String domainId,
  });

  /// Create domain alias.
  ///
  /// Create a dedicated hostname pinned to a team of the domain.
  ///
  /// [domainId] - Domain ID.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/admin/domains/{domainId}/aliases')
  Future<AdminDomainAliasDto> createDomainAlias({
    @Path('domainId') required String domainId,
    @Body() required CreateDomainAliasRequest body,
  });

  /// Update domain alias.
  ///
  /// Update a dedicated hostname's pinned team or branding.
  ///
  /// [aliasId] - Alias ID.
  ///
  /// [domainId] - Domain ID.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/admin/domains/{domainId}/aliases/{aliasId}')
  Future<AdminDomainAliasDto> updateDomainAlias({
    @Path('aliasId') required String aliasId,
    @Path('domainId') required String domainId,
    @Body() required UpdateDomainAliasRequest body,
  });

  /// Delete domain alias.
  ///
  /// Delete a dedicated hostname.
  ///
  /// [aliasId] - Alias ID.
  ///
  /// [domainId] - Domain ID.
  @DELETE('/api/admin/domains/{domainId}/aliases/{aliasId}')
  Future<void> deleteDomainAlias({
    @Path('aliasId') required String aliasId,
    @Path('domainId') required String domainId,
  });

  /// Toggle domain alias active status.
  ///
  /// Enable or disable a dedicated hostname.
  ///
  /// [aliasId] - Alias ID.
  ///
  /// [domainId] - Domain ID.
  @POST('/api/admin/domains/{domainId}/aliases/{aliasId}/toggle-active')
  Future<AdminDomainAliasDto> toggleDomainAliasActive({
    @Path('aliasId') required String aliasId,
    @Path('domainId') required String domainId,
  });

  /// List GPS credentials.
  ///
  /// Get all GPS credentials for a domain.
  ///
  /// [domainId] - Domain ID.
  @GET('/api/admin/domains/{domainId}/gps-credentials')
  Future<List<AdminGpsCredentialDto>> listDomainGpsCredentials({
    @Path('domainId') required String domainId,
  });

  /// Create GPS credential.
  ///
  /// Create a new GPS credential for a domain.
  ///
  /// [domainId] - Domain ID.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/admin/domains/{domainId}/gps-credentials')
  Future<AdminGpsCredentialDto> createDomainGpsCredential({
    @Path('domainId') required String domainId,
    @Body() required CreateGpsCredentialRequest body,
  });

  /// Update GPS credential.
  ///
  /// Update a GPS credential for a domain.
  ///
  /// [credentialId] - Credential ID.
  ///
  /// [domainId] - Domain ID.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/admin/domains/{domainId}/gps-credentials/{credentialId}')
  Future<AdminGpsCredentialDto> updateDomainGpsCredential({
    @Path('credentialId') required String credentialId,
    @Path('domainId') required String domainId,
    @Body() required UpdateGpsCredentialRequest body,
  });

  /// Delete GPS credential.
  ///
  /// Delete a GPS credential for a domain.
  ///
  /// [credentialId] - Credential ID.
  ///
  /// [domainId] - Domain ID.
  @DELETE('/api/admin/domains/{domainId}/gps-credentials/{credentialId}')
  Future<void> deleteDomainGpsCredential({
    @Path('credentialId') required String credentialId,
    @Path('domainId') required String domainId,
  });

  /// Toggle domain active status.
  ///
  /// Enable or disable a domain.
  ///
  /// [domainId] - Domain ID.
  @POST('/api/admin/domains/{domainId}/toggle-active')
  Future<AdminDomainDto> toggleDomainActive({
    @Path('domainId') required String domainId,
  });
}
