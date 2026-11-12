import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/deleted_badge.dart';
import '../../../../keys.dart';
import '../../../tags/presentation/content_tags.dart';

/// La carte d'une annonce dans la liste de la rubrique.
///
/// Bandeau de 120 px — la photo quand il y en a une, le dégradé `gradAd` et
/// l'icône sinon —, titre, pile de badges, extrait de deux lignes, puis la
/// rangée prix · date · lieu.
///
/// L'extrait vient d'`excerpt` et **jamais** de `media.markdown` : la liste
/// est chargée en `COMPACT`, où le corps n'est pas envoyé du tout.
///
/// La carte prend un DTO, elle vit donc dans son *feature* et n'a pas de
/// préfixe `Pdl` (§1.2.5).
class AdCard extends StatelessWidget {
  const AdCard({super.key, required this.ad});

  final AdDto ad;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final AdType type = AdType.fromJson(ad.adType);
    final DateTime? at = AppFormatters.tryParseDisplayTime(ad.createdAt);
    final FormattedPrice price = AppFormatters.formatPrice(
      ad.price,
      rentalPeriod: ad.rentalPeriod,
    );

    return PdlCard(
      key: keys.adsList.card(ad.slug),
      padding: PdlCardPadding.none,
      onTap: () => context.push(Paths.ad(ad.team.slug, ad.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlCardMedia(
            tone: PdlMediaTone.ad,
            icon: PdlIcons.ad,
            imageUrl: ad.thumbnailUrl,
            height: PdlMetrics.media120,
            borderRadius: BorderRadius.zero,
          ),
          Padding(
            padding: const EdgeInsets.all(PdlSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            ad.name,
                            style: t.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ad.excerpt != null &&
                              ad.excerpt!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              ad.excerpt!,
                              style: t.sub,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: PdlSpacing.chipGap),
                    // Ordre de lecture de `PdlBadgeStack` : type, statut,
                    // visibilité. Le statut publié et la visibilité d'équipe
                    // sont les cas courants et ne portent aucune information —
                    // ils ne se badgent pas.
                    PdlBadgeStack(
                      badges: <Widget>[
                        // Supprimé → type → état (règle R1, KIT §9).
                        ...deletedBadgeFirst(ad.deleted),
                        PdlBadge(
                          label: 'ads.adType.${ad.adType}'.tr(),
                          tone: type.tone(c),
                        ),
                        if (ad.status == 'DRAFT')
                          PdlBadge(
                            label: 'status.draft'.tr(),
                            tone: Status.draft.tone(c),
                          ),
                      ],
                    ),
                  ],
                ),
                if (ad.tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  ContentTagRow(tags: ad.tags, maxVisible: kCardTagLimit),
                ],
                const SizedBox(height: PdlSpacing.cardTight),
                PdlStatRow(
                  stats: <PdlStat>[
                    // Les trois formes de prix sortent toutes d'un seul
                    // formateur : ferme « 1 200,00 € », périodique
                    // « 1 200,00 € / jour », et « Prix à négocier » — jamais
                    // un tiret.
                    PdlStat(
                      value: price.period == null
                          ? price.amount
                          : '${price.amount} ${price.period}',
                      icon: PdlIcons.price,
                    ),
                    if (at != null)
                      PdlStat(
                        // Courte avec l'heure (KIT §9) : « jeu. 5 nov. ·
                        // 18:42 ».
                        value: AppFormatters.formatTimestamp(at),
                        icon: PdlIcons.date,
                      ),
                    // Un secteur, jamais une épingle : la position est
                    // floutée à ~1 km (ledger `MOB-139`, D11 ; KIT §9).
                    if (ad.locationDescription != null &&
                        ad.locationDescription!.isNotEmpty)
                      PdlStat(
                        value: 'ads.sector'.tr(
                          namedArgs: <String, String>{
                            'place': ad.locationDescription!,
                          },
                        ),
                      ),
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
