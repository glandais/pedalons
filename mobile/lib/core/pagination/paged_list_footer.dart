import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../pdl/pdl_paged_list_footer.dart';
import '../utils/formatters.dart';
import 'paged_list_state.dart';

/// Foot of an infinitely scrolled list.
///
/// Façade **traduite** au-dessus de [PdlPagedListFooter] (B9) : le rendu, lui,
/// vit dans `core/pdl`, qui ne traduit rien. Ce qui reste ici est la lecture du
/// [PagedListState] et les clés de localisation.
///
/// Le compteur porte **toujours le total** (« 8 participants sur 40 ») : un
/// « Chargement… » nu ne dit ni où on en est, ni combien il reste. Le total
/// vient de [PagedListState.total], renvoyé par le serveur avec la première
/// page ; tant qu'il manque, seul le nombre chargé est affiché.
class PagedListFooter extends StatelessWidget {
  final PagedListState<Object?> state;
  final VoidCallback onRetry;

  /// Optional placeholder shown above the spinner while the next page loads,
  /// so the list grows into the incoming content instead of jumping.
  final Widget? skeleton;

  /// Clé de traduction du nom de ce qui est compté, à formes `one`/`other` —
  /// accordé au nombre chargé : « 1 personne sur 1 », « 8 personnes sur 40 »
  /// (docs/LEDGER_*.md MOB-139, N7). Absent, le compteur reste « 8 sur 40 ».
  final String? itemNounKey;

  const PagedListFooter({
    super.key,
    required this.state,
    required this.onRetry,
    this.skeleton,
    this.itemNounKey,
  });

  String _progressLabel() {
    final int loaded = state.items.length;
    final int? total = state.total;
    if (total == null) {
      return 'pagination.loaded'.tr(
        namedArgs: <String, String>{
          'loaded': AppFormatters.formatNumber(loaded),
        },
      );
    }
    if (itemNounKey == null) {
      return 'pagination.progress'.tr(
        namedArgs: <String, String>{
          'loaded': AppFormatters.formatNumber(loaded),
          'total': AppFormatters.formatNumber(total),
        },
      );
    }
    return pagedProgressNamed(itemNounKey!, loaded, total);
  }

  @override
  Widget build(BuildContext context) {
    return PdlPagedListFooter(
      isLoadingNext: state.isLoadingNext,
      hasMore: state.hasMore,
      isEmpty: state.items.isEmpty,
      hasError: state.nextError != null,
      onRetry: onRetry,
      skeleton: skeleton,
      progressLabel: _progressLabel(),
      loadingLabel: 'pagination.loadingMore'.tr(),
      endLabel: 'pagination.endOfList'.tr(),
      errorLabel: 'pagination.nextPageError'.tr(),
      retryLabel: 'common.retry'.tr(),
    );
  }
}

/// « 60 membres sur 1 999 », « 1 membre sur 1 » : le nom ([nounKey], à formes
/// `one`/`other`) s'accorde au nombre chargé, et les deux nombres passent par
/// le formateur commun (docs/LEDGER_*.md MOB-139, N7).
String pagedProgressNamed(String nounKey, int loaded, int total) =>
    'pagination.progressNamed'.tr(
      namedArgs: <String, String>{
        'loaded': AppFormatters.formatNumber(loaded),
        'noun': nounKey.plural(loaded),
        'total': AppFormatters.formatNumber(total),
      },
    );
