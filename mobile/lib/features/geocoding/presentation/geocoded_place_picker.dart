import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../core/material.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../../core/theme/pdl_typography.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../rides/presentation/widgets/editor/search_picker_sheet.dart';
import '../data/place_search_repository.dart';

/// Pourquoi la position d'une adresse choisie n'a pas pu être lue.
enum GeocodeFailure {
  /// Le relais de géocodage ne répond pas (`GEOCODING_UNAVAILABLE`).
  unavailable,

  /// Tout autre échec, ou une réponse sans position.
  failed;

  /// Le message à montrer, dans la langue de l'app.
  String get message => switch (this) {
    GeocodeFailure.unavailable => 'geocoder.unavailable'.tr(),
    GeocodeFailure.failed => 'geocoder.resolveFailed'.tr(),
  };
}

/// Ce que rend [pickGeocodedPlace] quand une adresse a été choisie : sa
/// position ([GeocodedPlace]), ou l'échec de sa lecture
/// ([GeocodedPlaceFailure]).
@immutable
sealed class GeocodedPick {
  const GeocodedPick();
}

/// L'adresse choisie et sa position.
final class GeocodedPlace extends GeocodedPick {
  const GeocodedPlace({
    required this.name,
    required this.lat,
    required this.lon,
  });

  /// Le nom que la personne a lu et choisi dans la liste — pas celui de la
  /// résolution.
  final String name;
  final double lat;
  final double lon;

  /// Dans l'ordre GeoJSON, **`[longitude, latitude]`** : ce que prennent
  /// `TeamRequestGeometry`, `PlaceRequestGeometry` et
  /// `AdRequestLocationGeometry`, trois classes générées distinctes aux champs
  /// identiques — chaque formulaire construit la sienne.
  List<double> get coordinates => <double>[lon, lat];
}

/// La position de l'adresse choisie n'a pas pu être lue : le formulaire garde
/// la position qu'il avait, et le dit ([GeocodeFailure.message]).
final class GeocodedPlaceFailure extends GeocodedPick {
  const GeocodedPlaceFailure(this.reason);

  final GeocodeFailure reason;
}

/// Ouvre la recherche d'adresse, puis lit la position de l'adresse choisie —
/// une seule fois, pour celle-là (ledger `API-129`). Le sélecteur commun des
/// formulaires d'annonce, d'équipe et de lieu (docs/LEDGER_*.md MOB-165).
///
/// Rend `null` si la feuille a été fermée sans choix.
///
/// [onResolvingChange] est le signal « résolution en cours », l'équivalent du
/// `onResolvingChange` du site : `true` quand la lecture de la position part,
/// `false` quand elle revient. Le formulaire s'en sert pour désactiver
/// « Enregistrer » — enregistrer entre-temps enregistrerait l'ancienne
/// position, ou aucune. Il est appelé après un `await` : l'appelant y vérifie
/// `mounted`.
///
/// [title] est le titre de la feuille ; les autres libellés sont les clés
/// neutres `geocoder.*`. Le pied porte le crédit que les conditions du
/// fournisseur veulent visible.
Future<GeocodedPick?> pickGeocodedPlace(
  BuildContext context,
  WidgetRef ref, {
  String? title,
  ValueChanged<bool>? onResolvingChange,
}) async {
  // Lu avant tout `await` : l'écran peut être quitté pendant la recherche.
  final PlaceSearchRepository places = ref.read(placeSearchRepositoryProvider);
  final GeocodeResultDto? picked = await _showPlaceSearch(
    context,
    places,
    title ?? 'geocoder.label'.tr(),
  );
  if (picked == null) return null;

  // La suggestion vient le plus souvent **sans position**.
  double? lat = picked.lat;
  double? lon = picked.lon;
  if (lat == null || lon == null) {
    onResolvingChange?.call(true);
    try {
      final GeocodeResultDto place = await places.resolve(picked.id);
      lat = place.lat;
      lon = place.lon;
    } catch (error, stackTrace) {
      return GeocodedPlaceFailure(
        resolveApiError(error, stackTrace).code == 'GEOCODING_UNAVAILABLE'
            ? GeocodeFailure.unavailable
            : GeocodeFailure.failed,
      );
    } finally {
      onResolvingChange?.call(false);
    }
  }
  if (lat == null || lon == null) {
    return const GeocodedPlaceFailure(GeocodeFailure.failed);
  }
  return GeocodedPlace(name: picked.displayName, lat: lat, lon: lon);
}

Future<GeocodeResultDto?> _showPlaceSearch(
  BuildContext context,
  PlaceSearchRepository places,
  String title,
) {
  return showSearchPickerSheet<GeocodeResultDto>(
    context,
    title: title,
    searchHint: 'geocoder.search'.tr(),
    emptyMessage: 'geocoder.empty'.tr(),
    idOf: (GeocodeResultDto place) => place.id,
    load: (String? search, int page) async {
      // Une seule page : le serveur rend cinq suggestions au plus.
      if (page > 0) return (items: const <GeocodeResultDto>[], total: 0);
      final List<GeocodeResultDto> results = await places.search(search ?? '');
      return (items: results, total: results.length);
    },
    itemBuilder: (BuildContext _, GeocodeResultDto place, VoidCallback onTap) =>
        PdlSettingRow(
          icon: PdlIcons.place,
          title: place.displayName,
          trailing: const SizedBox.shrink(),
          onTap: onTap,
        ),
    footerBuilder: (BuildContext sheetContext) {
      final PdlColors c = sheetContext.pdl;
      final PdlTypography t = sheetContext.pdlText;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: Text(
            'geocoder.attribution'.tr(),
            style: t.xs.copyWith(color: c.textDimmed),
          ),
        ),
      );
    },
  );
}
