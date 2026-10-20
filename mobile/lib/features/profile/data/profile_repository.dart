import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(usersClientProvider),
    ref.watch(gpsServicesClientProvider),
  );
});

/// Tout ce que l'écran de profil demande au serveur.
///
/// Un seul dépôt plutôt qu'un par section : ce sont dix appels sur le même
/// utilisateur, et les éclater en dix fichiers rendrait plus difficile de voir
/// ce qui est réellement disponible — c'est précisément ce qui a laissé
/// `logout-all` câblé nulle part pendant un an.
class ProfileRepository {
  ProfileRepository(this._users, this._gps);

  final UsersClient _users;
  final GpsServicesClient _gps;

  Future<UserDto> updateDisplayName(String displayName) {
    return _users.updateMe(body: UpdateUserRequest(displayName: displayName));
  }

  Future<UserDto> uploadAvatar(String filePath) {
    return _users.uploadAvatar(file: MultipartFile.fromFileSync(filePath));
  }

  Future<UserDto> deleteAvatar() => _users.deleteAvatar();

  Future<void> deleteAccount() => _users.deleteCurrentUser();

  /// L'état de chaque sujet du profil, pour sa vue d'ensemble.
  Future<ProfileSummaryDto> profileSummary() => _users.getMyProfileSummary();

  /// Ce que la suppression du compte ferait à ses équipes : celles qui partent
  /// avec lui, celles qui la refusent (`SOLE_TEAM_ADMIN`, ou
  /// `SOLE_MIGRATED_TEAM_ADMIN` pour une équipe venue de biketeam).
  Future<AccountDeletionImpactDto> deletionImpact() =>
      _users.getMyDeletionImpact();

  /// L'export RGPD le plus récent, ou `null` quand il n'y en a jamais eu.
  ///
  /// L'absence d'export est un **404**, pas une liste vide : sans ce filet,
  /// l'écran afficherait « Chargement impossible » à tout utilisateur qui n'a
  /// jamais rien demandé, c'est-à-dire à presque tous.
  Future<UserExportDto?> latestExport() async {
    try {
      return await _users.getLatestExport();
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<UserExportDto> requestExport() => _users.requestExport();

  /// Les services GPS que **le serveur** propose. Jamais une liste codée en
  /// dur : un service ajouté au backend apparaît sans livrer de mobile.
  Future<List<GpsServiceType>> availableGpsServices() =>
      _gps.getAvailableServices();

  /// L'adresse d'autorisation du fournisseur. [returnTo] dit où son retour
  /// ramène le navigateur : le profil, ou la page d'appairage d'un Karoo
  /// (docs/LEDGER_*.md API-63).
  Future<String> gpsConnectUrl(
    GpsServiceType service, {
    GpsConnectReturn returnTo = GpsConnectReturn.profile,
  }) async {
    final GpsOAuthUrlResponse response = await _gps.getConnectUrl(
      serviceType: service,
      returnTo: returnTo,
    );
    return response.authorizationUrl;
  }

  Future<void> disconnectGps(GpsServiceType service) =>
      _gps.disconnect(serviceType: service);

  /// Active ou coupe l'envoi automatique des parcours vers [service]
  /// (docs/LEDGER_*.md API-120). Couper retire de chez le service les
  /// parcours à venir que l'envoi automatique y a déposés. La connexion
  /// rendue porte l'état recalculé par le serveur.
  Future<GpsServiceConnectionDto> setGpsAutoSync(
    GpsServiceType service, {
    required bool enabled,
  }) => _gps.setGpsAutoSync(
    serviceType: service,
    body: GpsAutoSyncRequest(enabled: enabled),
  );

  /// Les Karoo et Garmin appairés au compte (docs/LEDGER_*.md API-64).
  Future<List<PairedDeviceDto>> pairedDevices() => _users.listPairedDevices();

  Future<void> unpairDevice(String deviceId) =>
      _users.unpairDevice(deviceId: deviceId);
}
