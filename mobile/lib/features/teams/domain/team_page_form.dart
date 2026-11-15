import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../rides/domain/ride_form.dart' show kRideMarkdownMaxLength;
import '../../visibility/domain/content_visibility.dart';

/// Borne de `TeamPageRequest.title` au contrat. Le texte (`MediaDto`) a celle
/// de la sortie : [kRideMarkdownMaxLength], le même DTO.
const int kTeamPageTitleMaxLength = 100;

/// Le nombre de pages personnalisées d'une équipe, au plus — le serveur
/// refuse au-delà (`TOO_MANY_TEAM_PAGES`). Seules les pages **non supprimées**
/// comptent (`TeamPageRepository.countAdditionalPages`).
const int kTeamPageLimit = 3;

/// Les pages qui comptent dans la limite : celles qui ne sont pas à la
/// corbeille.
int liveTeamPageCount(List<TeamPageSummaryDto> pages) =>
    pages.where((TeamPageSummaryDto page) => !page.deleted).length;

/// Les identifiants de [pages] une fois la page d'index [index] déplacée d'un
/// rang ([up] : vers le haut), ou `null` si elle est déjà au bout.
///
/// **La liste entière**, pages supprimées comprises, comme le site l'envoie
/// (`pages.map((p) => p.id)`) : `reorderPages` pose `pageOrder = i` sur chaque
/// identifiant reçu et ne touche pas aux autres — une liste partielle
/// laisserait deux pages au même rang.
List<String>? movedTeamPageIds(
  List<TeamPageSummaryDto> pages,
  int index, {
  required bool up,
}) {
  final int target = up ? index - 1 : index + 1;
  if (index < 0 || index >= pages.length) return null;
  if (target < 0 || target >= pages.length) return null;
  final List<String> ids = <String>[
    for (final TeamPageSummaryDto page in pages) page.id,
  ];
  final String moved = ids[index];
  ids[index] = ids[target];
  ids[target] = moved;
  return ids;
}

/// Le formulaire d'une page personnalisée : ce que `TeamPageRequest` porte.
@immutable
class TeamPageForm {
  const TeamPageForm({
    required this.title,
    required this.media,
    required this.visibility,
  });

  /// Le formulaire vide du site (`CreateTeamPagePage`) : « Équipe » quelle
  /// que soit l'équipe — une page est son texte à elle, ouverte exprès —,
  /// sinon la première valeur que le backend permet
  /// (`team.allowedContentVisibilities.teamPage`, ledger `MOB-137`).
  factory TeamPageForm.initial(TeamDetailDto team) {
    final List<Visibility> allowed = allowedVisibilitiesFor(
      team,
      VisibilityKind.teamPage,
    );
    return TeamPageForm(
      title: '',
      media: const MediaDto(
        markdown: '',
        assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
      ),
      visibility: allowed.contains(Visibility.team)
          ? Visibility.team
          : (allowed.firstOrNull ?? Visibility.team),
    );
  }

  /// La page telle qu'elle est, prête à être réécrite : le PUT pose le titre,
  /// la visibilité et **tous** les médias — texte, logo, images, pièces
  /// jointes. Un formulaire intact les renvoie donc tous.
  factory TeamPageForm.fromPage(TeamPageDto page) => TeamPageForm(
    title: page.title,
    media: page.media,
    visibility: Visibility.fromJson(page.visibility),
  );

  final String title;
  final MediaDto media;
  final Visibility visibility;

  TeamPageForm copyWith({
    String? title,
    MediaDto? media,
    Visibility? visibility,
  }) => TeamPageForm(
    title: title ?? this.title,
    media: media ?? this.media,
    visibility: visibility ?? this.visibility,
  );

  TeamPageRequest toRequest() => TeamPageRequest(
    title: title.trim(),
    media: media,
    visibility: visibility.toJson(),
  );

  // --- Validation : les contraintes de `TeamPageRequest`, lues avant
  // d'envoyer.

  /// 1 à [kTeamPageTitleMaxLength] caractères, dont un au moins n'est pas un
  /// blanc.
  bool get titleValid {
    final int length = title.trim().length;
    return length >= 1 && length <= kTeamPageTitleMaxLength;
  }

  bool get markdownValid => media.markdown.length <= kRideMarkdownMaxLength;

  bool get isValid => titleValid && markdownValid;
}
