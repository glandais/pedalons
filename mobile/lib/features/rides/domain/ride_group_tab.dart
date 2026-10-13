/// Les trois onglets de la page d'un groupe.
enum RideGroupTab {
  overview,
  weather,
  participants;

  /// La valeur de `?tab=` — hors contrat, pour les liens internes.
  String get query => name;

  /// `?tab=weather` ouvre l'onglet Météo ; une valeur absente ou inconnue,
  /// l'Aperçu.
  static RideGroupTab fromQuery(String? value) {
    for (final RideGroupTab tab in RideGroupTab.values) {
      if (tab.query == value) return tab;
    }
    return RideGroupTab.overview;
  }
}
