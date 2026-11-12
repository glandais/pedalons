import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../data/calendar_repository.dart';

/// Le jeton, lu **à chaque ouverture du bloc** et jamais au-delà.
///
/// `autoDispose` n'est pas un détail de performance ici : c'est ce qui garantit
/// que le jeton quitte la mémoire dès que le bloc sort de l'écran. Il n'est
/// **jamais** écrit dans `shared_preferences`, jamais journalisé, jamais rendu
/// en clair (§3.2).
final calendarTokenProvider = FutureProvider.autoDispose<CalendarTokenDto>(
  (ref) => ref.watch(calendarRepositoryProvider).getToken(),
);

/// Ce que l'utilisateur voit d'une URL de flux : tout, sauf le jeton.
///
/// `https://pedalons.fr/api/calendar/abc123.ics` devient
/// `https://pedalons.fr/api/calendar/••••••••.ics`. On masque le **dernier
/// segment de chemin, avant son extension**, ce qui couvre les deux gabarits
/// servis (`globalFeedUrl` et `teamFeedUrlTemplate`) sans supposer leur forme,
/// et on retire toute chaîne de requête — un jeton s'y cache tout aussi bien.
String maskCalendarFeedUrl(String url) {
  // Manipulation de chaîne et non `Uri.replace` : ce dernier ré-encode les
  // puces en `%E2%80%A2`, ce qui rend l'URL masquée illisible.
  final int queryStart = url.indexOf(RegExp(r'[?#]'));
  final String path = queryStart == -1 ? url : url.substring(0, queryStart);
  final int slash = path.lastIndexOf('/');
  if (slash < 0) return _mask;

  final String last = path.substring(slash + 1);
  final int dot = last.lastIndexOf('.');
  final String extension = dot > 0 ? last.substring(dot) : '';
  return '${path.substring(0, slash + 1)}$_mask$extension';
}

const String _mask = '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022';

/// « Abonnement calendrier » : le bloc qui donne le flux ICS sans jamais
/// montrer le jeton.
///
/// Trois règles non négociables (§3.2), et elles sont toutes de sécurité, pas
/// de rendu :
///
/// 1. **l'URL s'affiche masquée** — pas de `SelectableText`, qui permettrait de
///    copier le jeton par sélection, et rien qui puisse le laisser dans une
///    capture d'écran ou un journal ;
/// 2. **seul le presse-papiers reçoit l'URL réelle**, sur une action explicite ;
/// 3. **la régénération passe par une question fermée** — l'ancien lien cesse
///    de fonctionner sur tous les appareils, et c'est irréversible.
class CalendarSubscriptionCard extends ConsumerStatefulWidget {
  const CalendarSubscriptionCard({super.key, this.teamSlug});

  /// Quand il est fourni, c'est le flux de cette équipe qui est proposé.
  final String? teamSlug;

  @override
  ConsumerState<CalendarSubscriptionCard> createState() =>
      _CalendarSubscriptionCardState();
}

class _CalendarSubscriptionCardState
    extends ConsumerState<CalendarSubscriptionCard> {
  /// Message d'issue — copie faite, abonnement impossible, régénération.
  String? _notice;
  PdlBannerTone _noticeTone = PdlBannerTone.info;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final AsyncValue<CalendarTokenDto> token = ref.watch(calendarTokenProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.section,
        PdlSpacing.section,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlSectionHeader(
            title: 'calendar.subscription.title'.tr(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          PdlBanner(
            tone: PdlBannerTone.info,
            message: 'calendar.subscription.help'.tr(),
          ),
          const SizedBox(height: PdlSpacing.cardTight),
          switch (token) {
            // Pendant une relecture (après « Régénérer »), Riverpod garde
            // l'ancien jeton en `AsyncData` avec `isLoading` : affiché, mais
            // ni copiable ni proposé à l'abonnement — il ne marche plus.
            AsyncData<CalendarTokenDto>(:final CalendarTokenDto value) => _body(
              c,
              t,
              value,
              stale: token.isLoading,
            ),
            AsyncError<CalendarTokenDto>(:final Object error) => PdlBanner(
              tone: PdlBannerTone.danger,
              message: getErrorMessage(error),
              action: PdlButton(
                variant: PdlButtonVariant.text,
                label: 'common.retry'.tr(),
                onPressed: () => ref.invalidate(calendarTokenProvider),
              ),
            ),
            _ => const PdlSkeleton(width: double.infinity, height: 44),
          },
          if (_notice != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.cardTight),
            PdlBanner(
              key: keys.calendar.subscriptionNotice,
              tone: _noticeTone,
              message: _notice!,
              onDismiss: () => setState(() => _notice = null),
              dismissSemanticLabel: 'common.close'.tr(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(
    PdlColors c,
    PdlTypography t,
    CalendarTokenDto token, {
    required bool stale,
  }) {
    final String url = _feedUrl(token);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: PdlMetrics.tapTarget,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: PdlRadii.mdAll,
                  border: Border.all(color: c.border),
                ),
                // `Text` et **jamais** `SelectableText` : une sélection rendrait
                // le jeton copiable caractère par caractère, ce que le masquage
                // interdit précisément.
                child: Text(
                  maskCalendarFeedUrl(url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.mono.copyWith(color: c.text),
                ),
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            PdlAppBarAction(
              key: keys.calendar.subscriptionCopyButton,
              icon: PdlIcons.copy,
              semanticLabel: 'calendar.subscription.copy'.tr(),
              onPressed: stale ? null : () => _copy(url),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('calendar.subscription.tokenHidden'.tr(), style: t.xs),
        const SizedBox(height: PdlSpacing.cardTight),
        Row(
          children: <Widget>[
            Expanded(
              child: PdlButton(
                icon: PdlIcons.calendar,
                label: 'calendar.subscription.subscribe'.tr(),
                fullWidth: true,
                onPressed: stale ? null : () => _subscribe(url),
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            Expanded(
              child: PdlButton(
                key: keys.calendar.subscriptionRegenerateButton,
                variant: PdlButtonVariant.outline,
                label: 'calendar.subscription.regenerate'.tr(),
                fullWidth: true,
                onPressed: _confirmRegenerate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _feedUrl(CalendarTokenDto token) {
    final String? slug = widget.teamSlug;
    if (slug == null) return token.globalFeedUrl;
    return token.teamFeedUrlTemplate.replaceAll('{teamSlug}', slug);
  }

  Future<void> _copy(String url) async {
    // **Le seul endroit où l'URL réelle circule.**
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _notify('calendar.subscription.copied'.tr(), PdlBannerTone.info);
  }

  /// « S'abonner » lance `webcal://`, que les applications de calendrier
  /// enregistrent. Sans gestionnaire, on ne laisse pas l'utilisateur devant un
  /// bouton mort : on copie et on le dit.
  Future<void> _subscribe(String url) async {
    final Uri webcal = Uri.parse(
      url.replaceFirst(RegExp(r'^https?://'), 'webcal://'),
    );
    bool launched = false;
    try {
      launched = await launchUrl(webcal, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (launched || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _notify('calendar.subscription.noHandler'.tr(), PdlBannerTone.warn);
  }

  /// Question fermée : le libellé dit la conséquence, pas l'action.
  Future<void> _confirmRegenerate() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('calendar.subscription.regenerateTitle'.tr()),
        content: Text('calendar.subscription.regenerateWarning'.tr()),
        actions: <Widget>[
          PdlButton(
            variant: PdlButtonVariant.text,
            label: 'common.cancel'.tr(),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PdlButton(
            key: keys.calendar.subscriptionRegenerateConfirmButton,
            variant: PdlButtonVariant.danger,
            label: 'calendar.subscription.regenerate'.tr(),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(calendarRepositoryProvider).regenerateToken();
      if (!mounted) return;
      // Le jeton neuf se relit, il ne se garde pas — et l'issue ne s'annonce
      // qu'une fois relu : jusque-là, l'URL affichée est celle de l'ancien.
      final CalendarTokenDto _ = await ref.refresh(
        calendarTokenProvider.future,
      );
      if (!mounted) return;
      _notify('calendar.subscription.regenerated'.tr(), PdlBannerTone.info);
    } catch (error) {
      if (!mounted) return;
      _notify(getErrorMessage(error), PdlBannerTone.danger);
    }
  }

  void _notify(String message, PdlBannerTone tone) => setState(() {
    _notice = message;
    _noticeTone = tone;
  });
}
