import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/card_header_image.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../keys.dart';
import '../../../visibility/presentation/visibility_badge.dart';

/// Débord du logo sous le bandeau, en pixels.
const double _kLogoOverhang = 20;

/// Diamètre du logo.
const double _kLogoSize = 56;

/// La carte d'une équipe sur l'écran de découverte.
///
/// Bandeau de 120 px — la photo de l'équipe, sinon `gradTeam` —, **logo de 56 px débordant de 20 px sous le
/// bandeau**, titre, « Équipe uniquement » sur une équipe privée, extrait de deux lignes, compte de
/// membres et action.
///
/// Le débord est la seule difficulté : il exige un [Stack] à
/// `clipBehavior: Clip.none` et un corps décalé de 26 px vers le bas. Un clip
/// parasite — celui de [PdlCard], qui découpe par défaut — rognerait la moitié
/// basse du logo sans rien signaler.
///
/// La carte prend un DTO : elle vit donc dans `features/teams/` et **n'a pas**
/// de préfixe `Pdl` (§1.2.5).
class TeamDiscoveryCard extends StatelessWidget {
  const TeamDiscoveryCard({
    super.key,
    required this.team,
    required this.onJoin,
    this.joining = false,
  });

  final TeamDetailDto team;

  /// Demande d'adhésion. Appelée seulement dans l'état « Rejoindre ».
  final VoidCallback onJoin;

  /// Un appel d'adhésion est en vol pour **cette** équipe.
  final bool joining;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;

    return PdlCard(
      padding: PdlCardPadding.none,
      onTap: () => pushLocation(context, Paths.team(team.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            // Sans cela, la moitié basse du logo disparaît — et rien ne le dit.
            clipBehavior: Clip.none,
            children: <Widget>[
              // La photo de l'équipe (la première image de sa page « À
              // propos ») si elle en a une, sinon le dégradé (règle R10).
              PdlCardMedia(
                tone: PdlMediaTone.team,
                icon: PdlIcons.team,
                imageUrl: firstPhotoUrl(team.about),
                height: PdlMetrics.media120,
                borderRadius: BorderRadius.zero,
              ),
              Positioned(
                left: PdlSpacing.section,
                bottom: -_kLogoOverhang,
                child: PdlAvatar(
                  name: team.name,
                  imageUrl: team.logoUrl,
                  size: _kLogoSize,
                  ring: true,
                ),
              ),
            ],
          ),
          Padding(
            // 26 px en tête : les 20 px de débord du logo, plus la gouttière.
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.card,
              _kLogoOverhang + 6,
              PdlSpacing.card,
              PdlSpacing.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: Text(team.name, style: t.cardTitle)),
                    // « Équipe uniquement » sur une équipe privée ; une équipe
                    // publique, le cas ordinaire, ne porte rien (règle R1).
                    for (final Widget badge in teamVisibilityBadges(
                      team.visibility,
                      key: keys.teamsDiscover.cardVisibility(team.slug),
                    )) ...<Widget>[
                      const SizedBox(width: PdlSpacing.chipGap),
                      badge,
                    ],
                  ],
                ),
                if (team.excerpt != null &&
                    team.excerpt!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    team.excerpt!,
                    style: t.sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: PdlSpacing.cardTight),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PdlStat(
                        // Accordé : « 1 membre » (ledger `MOB-139`, D3).
                        value: 'teams.membersList.count'.plural(
                          team.memberCount,
                        ),
                        icon: PdlIcons.people,
                      ),
                    ),
                    const SizedBox(width: PdlSpacing.chipGap),
                    _Action(team: team, onJoin: onJoin, joining: joining),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Les quatre états de l'action, et rien d'autre.
///
/// * `joinable && role == null` → « Rejoindre l'équipe », plein ;
/// * appel en vol → contour grisé « Adhésion… » ;
/// * `role != null` → badge « Membre » et « Voir l'équipe », contour ;
/// * `!joinable && role == null` → « Sur invitation », désactivé — l'équipe
///   existe, elle ne se rejoint simplement pas d'un bouton, et le dire vaut
///   mieux que de ne rien montrer.
class _Action extends StatelessWidget {
  const _Action({
    required this.team,
    required this.onJoin,
    required this.joining,
  });

  final TeamDetailDto team;
  final VoidCallback onJoin;
  final bool joining;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    if (joining) {
      return PdlButton(
        label: 'teams.discovery.joining'.tr(),
        variant: PdlButtonVariant.outline,
        size: PdlButtonSize.sm,
        loading: true,
        loadingLabel: 'teams.discovery.joining'.tr(),
      );
    }

    if (team.role != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlBadge(
            label: 'teams.discovery.memberBadge'.tr(),
            tone: PdlDerivedTones.registered(c),
            icon: PdlIcons.check,
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          PdlButton(
            label: 'teams.viewTeam'.tr(),
            variant: PdlButtonVariant.outline,
            size: PdlButtonSize.sm,
            onPressed: () => pushLocation(context, Paths.team(team.slug)),
          ),
        ],
      );
    }

    if (!team.joinable) {
      return PdlButton(
        label: 'teams.discovery.inviteOnly'.tr(),
        variant: PdlButtonVariant.outline,
        size: PdlButtonSize.sm,
        enabled: false,
      );
    }

    return PdlButton(
      label: 'teams.discovery.join'.tr(),
      size: PdlButtonSize.sm,
      onPressed: onJoin,
    );
  }
}
