import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'ride_detail_provider.dart';

/// Vrai quand le détail d'une sortie doit, à son prochain affichage, défiler
/// jusqu'à sa carte météo (ledger `MOB-69`).
///
/// La page d'un groupe d'une sortie solo cède la place au détail ; ouverte
/// sur son onglet Météo (`?tab=weather`), elle pose ce drapeau avant de
/// partir, et le détail le **consomme** — il le remet à `false` en
/// défilant. Pas `autoDispose` : le détail n'existe pas encore quand la page
/// du groupe le pose (remplacement, ouverture à froid).
final rideScrollToWeatherProvider = StateProvider.family<bool, RideKey>(
  (Ref ref, RideKey key) => false,
);
