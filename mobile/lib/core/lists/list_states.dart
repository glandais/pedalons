import 'package:easy_localization/easy_localization.dart';

import '../../features/feedback/presentation/report_problem_button.dart';
import '../material.dart';
import '../pdl/pdl.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import '../utils/api_error_handler.dart';
import '../utils/formatters.dart';

// Les états d'une page de liste, **les mêmes sur toutes les listes de l'app**
// (règles RL8, RL10 et RL11 des listes, `docs/plans/2026-11-10-etat-des-lieux-
// affichage/maquettes/KIT.md` §10). Une liste ne compose plus ses propres
// erreurs, vides filtrés ni compteurs : elle les prend ici, et c'est ce qui les
// garde semblables d'une liste à l'autre.
//
// Ces widgets traduisent : ils vivent hors de `core/pdl`, au-dessus de
// `PdlEmptyState` et de `PdlDeadEndEmpty`, qui font le rendu.

/// Un état de liste (erreur, refus, vide) posé au milieu de la place qui reste
/// sous la barre : le même emplacement sur toutes les listes en slivers.
class ListStateSliver extends StatelessWidget {
  const ListStateSliver({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SliverFillRemaining(hasScrollBody: false, child: Center(child: child));
}

/// RL11 — l'échec du chargement d'une liste, sous **une seule forme**.
///
/// - Une coupure réseau : « Pas de connexion », « Vérifiez votre connexion
///   internet, puis réessayez. », « Réessayer ». Rien à signaler : ce n'est pas
///   un défaut de l'app.
/// - Une panne du serveur : « Chargement impossible », un message qui dit ce
///   qui a échoué (le message du code métier quand le serveur en rend un, sinon
///   « Le serveur n'a pas pu répondre… »), « Réessayer » et « Signaler un
///   problème ».
///
/// Jamais de notification par-dessus : le bloc dit la panne, une fois. Un
/// refus d'accès (403) n'est pas une panne — voir [ListAccessRefused].
class ListLoadError extends StatelessWidget {
  const ListLoadError({
    super.key,
    required this.error,
    required this.onRetry,
    this.stackTrace,
    this.retryKey,
  });

  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final ApiError resolved = resolveApiError(error, stackTrace);
    final bool offline = resolved.isOffline;
    return PdlEmptyState(
      variant: PdlEmptyVariant.error,
      icon: offline ? PdlIcons.offline : null,
      title: offline ? 'errors.offline.title'.tr() : 'lists.error.title'.tr(),
      message: offline
          ? 'errors.offline.message'.tr()
          : resolved.kind == ApiErrorKind.api
          ? resolved.message
          : 'lists.error.serverMessage'.tr(),
      actions: <Widget>[
        PdlButton(
          key: retryKey,
          label: 'common.retry'.tr(),
          variant: PdlButtonVariant.outline,
          size: PdlButtonSize.sm,
          onPressed: onRetry,
        ),
        // Se tait seul hors connexion et sur un objet introuvable.
        ReportProblemButton(error: error, stackTrace: stackTrace),
      ],
    );
  }
}

/// RL11 — un refus d'accès n'est pas une erreur : un message propre, sans
/// rouge ni « Réessayer » (qui rendrait le même refus), et **une issue** :
/// « À propos de l'équipe ».
class ListAccessRefused extends StatelessWidget {
  const ListAccessRefused({
    super.key,
    required this.title,
    required this.message,
    required this.onAbout,
  });

  final String title;
  final String message;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) => PdlEmptyState(
    variant: PdlEmptyVariant.empty,
    icon: PdlIcons.visibilityTeam,
    title: title,
    message: message,
    actions: <Widget>[
      PdlButton(
        label: 'teams.aboutTeam'.tr(),
        variant: PdlButtonVariant.outline,
        size: PdlButtonSize.sm,
        onPressed: onAbout,
      ),
    ],
  );
}

/// RL10 — le vide **filtré** : « Aucun {objet} pour ces filtres », « Rien ne
/// correspond à : {filtres actifs}. », « Effacer les filtres ».
///
/// [filters] nomme ce qui est posé, dans l'ordre de la barre : une recherche
/// entre guillemets ([quotedSearch]), une période (« Je participe »,
/// « Passées »), un type, des tags, une portée écartée de son défaut. Un seul
/// geste en sort, « Effacer les filtres », qui lève tout cela (le tri reste).
///
/// Les parcours y ajoutent « Retirer le filtre {x} » et l'aperçu de ce qui
/// reviendrait, quand le serveur sait quel filtre libère le plus de
/// résultats.
class ListFilteredEmpty extends StatelessWidget {
  const ListFilteredEmpty({
    super.key,
    required this.title,
    required this.filters,
    required this.onClear,
    this.clearKey,
    this.removeFilterLabel,
    this.onRemoveFilter,
    this.previewChild,
  });

  final String title;
  final List<String> filters;
  final VoidCallback onClear;
  final Key? clearKey;
  final String? removeFilterLabel;
  final VoidCallback? onRemoveFilter;
  final Widget? previewChild;

  @override
  Widget build(BuildContext context) => PdlDeadEndEmpty(
    title: title,
    message: filteredEmptyMessage(filters),
    resetAllLabel: 'common.clearFilters'.tr(),
    onResetAll: onClear,
    resetAllKey: clearKey,
    removeFilterLabel: removeFilterLabel,
    onRemoveFilter: onRemoveFilter,
    previewChild: previewChild,
  );
}

/// « Rien ne correspond à : « monts » · Sorties. »
String filteredEmptyMessage(List<String> filters) =>
    'lists.emptyFiltered.message'.tr(
      namedArgs: <String, String>{'filters': filters.join(' · ')},
    );

/// Une recherche citée dans un vide filtré : « « monts » ».
String quotedSearch(String search) => 'lists.emptyFiltered.search'.tr(
  namedArgs: <String, String>{'search': search.trim()},
);

/// RL8 — le compteur d'une liste paginée : « 2 585 annonces », nombre
/// formaté, nom accordé. [key] est une clé à formes `one` / `other` dont le
/// texte porte `{}`.
String listCountLabel(String key, int total) =>
    key.plural(total, args: <String>[AppFormatters.formatNumber(total)]);

/// RL8 — la ligne du compteur, sous la barre de la liste, à gauche : le total
/// **filtré** seul quand un filtre est posé. L'appelant ne la pose pas à zéro :
/// l'état vide parle.
class ListResultCount extends StatelessWidget {
  const ListResultCount(this.label, {super.key, this.textKey});

  final String label;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      PdlSpacing.section,
      PdlSpacing.chipGap,
      PdlSpacing.section,
      4,
    ),
    child: Text(label, key: textKey, style: context.pdlText.count),
  );
}
