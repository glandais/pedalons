import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../../core/widgets/team_banner.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../data/ad_repository.dart';
import '../widgets/ad_contact_sheet.dart';
import '../widgets/ad_location_map.dart';

final adDetailProvider =
    FutureProvider.family<AdDto, ({String teamSlug, String adSlug})>((
      ref,
      params,
    ) async {
      final repository = ref.watch(adRepositoryProvider);
      return repository.getAd(params.teamSlug, params.adSlug);
    });

class AdDetailPage extends ConsumerWidget {
  final String teamSlug;
  final String adSlug;

  const AdDetailPage({super.key, required this.teamSlug, required this.adSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (teamSlug: teamSlug, adSlug: adSlug);
    final AsyncValue<AdDto> adAsync = ref.watch(adDetailProvider(params));

    return adAsync.when(
      data: (AdDto ad) => _AdDetailContent(ad: ad),
      loading: () => Scaffold(
        appBar: PdlAppBar(onBack: () => Navigator.of(context).maybePop()),
        // Défilable : deux gabarits à bandeau dépassent la hauteur d'un petit
        // écran, et un gabarit qui déborde rend une bande d'erreur rayée.
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(PdlSpacing.section),
          child: PdlSkeletonCardList(
            variant: PdlSkeletonCardVariant.media,
            count: 2,
          ),
        ),
      ),
      error: (Object error, StackTrace stack) => Scaffold(
        appBar: PdlAppBar(onBack: () => Navigator.of(context).maybePop()),
        body: Center(
          child: SingleChildScrollView(
            child: PdlEmptyState(
              variant: PdlEmptyVariant.error,
              title: 'common.loadError'.tr(),
              message: getErrorMessage(error, stack),
              actions: <Widget>[
                PdlButton(
                  label: 'common.retry'.tr(),
                  variant: PdlButtonVariant.outline,
                  onPressed: () => ref.invalidate(adDetailProvider(params)),
                ),
                ReportProblemButton(error: error, stackTrace: stack),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdDetailContent extends ConsumerStatefulWidget {
  const _AdDetailContent({required this.ad});

  final AdDto ad;

  @override
  ConsumerState<_AdDetailContent> createState() => _AdDetailContentState();
}

class _AdDetailContentState extends ConsumerState<_AdDetailContent> {
  /// Vrai une fois le message parti : la confirmation est un **état** de
  /// l'écran, pas un `SnackBar` qui disparaît avant d'être lu.
  bool _messageSent = false;

  /// Vrai quand le serveur a répondu `AD_CONTACT_OPTED_OUT` : l'auteur s'est
  /// rendu injoignable, et réessayer n'y changerait rien.
  bool _optedOut = false;

  AdDto get ad => widget.ad;

  Future<void> _contact() async {
    final AdContactOutcome? outcome = await showAdContactSheet(
      context,
      teamSlug: ad.team.slug,
      adSlug: ad.slug,
      sellerName: ad.createdByDisplayName,
    );
    if (!mounted || outcome == null) return;
    setState(() {
      _messageSent = outcome == AdContactOutcome.sent;
      _optedOut = outcome == AdContactOutcome.optedOut;
    });
  }

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
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: PdlAppBar(
        // Pas de titre : le corps porte déjà le nom en 22/700, juste
        // dessous. Le répéter en 17 dans la barre le dit deux fois.
        onBack: () => Navigator.of(context).maybePop(),
        backSemanticLabel: 'ads.title'.tr(),
        // Sa propre annonce ne se signale pas et son auteur ne se bloque
        // pas : le menu serait vide, le bouton n'existe donc pas.
        actions: <Widget>[
          if (currentUserId != null && currentUserId != ad.createdById)
            PdlAppBarAction(
              key: keys.ad.moreButton,
              icon: PdlIcons.more,
              semanticLabel: 'moderation.more'.tr(),
              onPressed: () => showDetailModerationMenu(
                context,
                subject: ModerationSubject(
                  teamSlug: ad.team.slug,
                  type: ReportTargetType.ad,
                  id: ad.id,
                  teamName: ad.team.name,
                ),
                blockUserId: ad.createdById,
                blockUserName: ad.createdByDisplayName,
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            sliver: SliverList.list(
              children: <Widget>[
                TeamBanner(team: ad.team),
                const SizedBox(height: PdlSpacing.cardTight),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        ad.name,
                        key: keys.ad.title,
                        style: t.screenTitle,
                      ),
                    ),
                    const SizedBox(width: PdlSpacing.chipGap),
                    PdlBadgeStack(
                      badges: <Widget>[
                        PdlBadge(
                          label: 'ads.adType.${ad.adType}'.tr(),
                          tone: type.tone(c),
                          size: PdlBadgeSize.lg,
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
                if (at != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(AppFormatters.formatFullDate(at), style: t.sub),
                ],
                if (ad.tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  ContentTagRow(tags: ad.tags),
                ],
                const SizedBox(height: PdlSpacing.section),
                // `note` porte la période d'une location et rien d'autre : le
                // lieu a sa propre section, et l'absence de prix est déjà dite
                // par `amount` — « Prix à négocier », jamais un tiret.
                PdlPriceBlock(price: price.amount, note: price.period),
                if (ad.media.markdown.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.section),
                  PdlSectionHeader(title: 'ads.detail.description'.tr()),
                  MarkdownContent(
                    data: ad.media.markdown,
                    images: ad.media.assets.images,
                  ),
                ],
                // Les fichiers joints à l'annonce — facture, notice, fiche
                // technique. Ils voyagent dans `media.assets.attachments`,
                // servi en entier par `getAd` : la liste, elle, est chargée en
                // `COMPACT` et ne les porte pas, d'où leur absence de la carte.
                MediaAttachments(attachments: ad.media.assets.attachments),
                if (ad.locationGeometry != null ||
                    ad.locationDescription != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.section),
                  PdlSectionHeader(
                    key: keys.ad.location,
                    title: 'ads.detail.location'.tr(),
                  ),
                  if (ad.locationDescription != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: PdlSpacing.chipGap,
                      ),
                      child: PdlStat(
                        key: keys.ad.locationDescription,
                        value: ad.locationDescription!,
                        icon: PdlIcons.place,
                      ),
                    ),
                  // Aucune carte quand la géométrie manque : le lieu écrit se
                  // suffit, et une carte centrée sur un repli mentirait.
                  if (ad.locationGeometry != null)
                    AdLocationMap(geometry: ad.locationGeometry!),
                ],
                const SizedBox(height: PdlSpacing.section),
                PdlSectionHeader(
                  key: keys.ad.seller,
                  title: 'ads.detail.seller'.tr(),
                ),
                PdlPersonRow(name: ad.createdByDisplayName),
                if (_messageSent) ...<Widget>[
                  const SizedBox(height: PdlSpacing.cardTight),
                  // `PdlBannerTone` n'a pas de teinte « succès » et n'en
                  // gagne pas une pour l'occasion : `info` porte la même
                  // paire primaire, et l'icône dit le reste.
                  PdlBanner(
                    key: keys.ad.contactSent,
                    tone: PdlBannerTone.info,
                    icon: PdlIcons.checkCircle,
                    message: 'ads.contact.sent'.tr(),
                  ),
                ] else if (_optedOut) ...<Widget>[
                  const SizedBox(height: PdlSpacing.cardTight),
                  PdlBanner(
                    key: keys.ad.contactOptedOut,
                    tone: PdlBannerTone.warn,
                    message: 'ads.contact.optedOut'.tr(),
                  ),
                ] else if (currentUserId != ad.createdById) ...<Widget>[
                  // Le bouton **n'existe pas** sur sa propre annonce : se
                  // relayer un message à soi-même n'est pas une action.
                  const SizedBox(height: PdlSpacing.cardTight),
                  PdlButton(
                    key: keys.ad.contactButton,
                    label: 'ads.contact.cta'.tr(),
                    icon: PdlIcons.email,
                    fullWidth: true,
                    onPressed: _contact,
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
