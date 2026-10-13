import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../data/ride_repository.dart';
import 'ride_detail_provider.dart';

/// La météo d'une sortie (`GET …/rides/{rideSlug}/weather`).
///
/// Partagée par la carte « Météo au départ » du détail, la ligne météo de ses
/// cartes de groupe et la page d'un groupe (son Aperçu et son onglet Météo),
/// que le détail pousse par-dessus lui : ouvrir la page ne recharge rien
/// (ledger `MOB-67`).
///
/// `autoDispose` : une prévision vieillit, et rien d'autre que ces
/// écrans ne la lit — la garder en mémoire après eux ne servirait qu'à
/// montrer une prévision périmée au retour. Le pull-to-refresh du détail et
/// celui de la page d'un groupe l'invalident explicitement.
///
/// Les calculs (passages, vent relatif, exposition, alerte pluie) sont tous
/// faits par le serveur : l'app n'en refait aucun, elle traduit et convertit
/// les unités.
final rideWeatherProvider = FutureProvider.autoDispose
    .family<RideWeatherDto, RideKey>(
      (Ref ref, RideKey key) => ref
          .watch(rideRepositoryProvider)
          .getRideWeather(key.teamSlug, key.rideSlug),
    );
