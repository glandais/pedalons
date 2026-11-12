import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../data/ad_repository.dart';

/// Bornes du message, imposées par `AdContactRequest` au contrat.
const int kAdContactMinLength = 10;
const int kAdContactMaxLength = 2000;

/// Ce que la feuille rapporte à l'écran qui l'a ouverte.
///
/// Les échecs récupérables — quota, relais en panne — **ne remontent pas** :
/// ils se traitent dans la feuille, brouillon en main. Seuls sortent le succès
/// et le refus définitif.
enum AdContactOutcome {
  /// 204 : le serveur a pris le message en charge.
  sent,

  /// 400 `AD_CONTACT_OPTED_OUT` : l'auteur s'est rendu injoignable. Réessayer
  /// n'y changera rien, l'écran désactive donc le bouton.
  optedOut,
}

/// Ouvre « Contacter le vendeur ».
Future<AdContactOutcome?> showAdContactSheet(
  BuildContext context, {
  required String teamSlug,
  required String adSlug,
  required String sellerName,
}) {
  return PdlSheet.show<AdContactOutcome>(
    context: context,
    builder: (BuildContext sheetContext) => _AdContactSheet(
      teamSlug: teamSlug,
      adSlug: adSlug,
      sellerName: sellerName,
    ),
  );
}

/// La feuille de contact d'un vendeur.
///
/// **Aucun succès optimiste.** Le bouton reste en cours tant que le serveur
/// n'a pas répondu 204, et les trois autres issues sont rendues telles
/// qu'elles sont : un relais qui avale le message est pire qu'un relais qui
/// échoue, parce que l'expéditeur attend alors une réponse qui n'arrivera
/// jamais.
///
/// **Le brouillon survit à l'échec** : le champ n'est ni vidé ni fermé, et
/// « Réessayer » renvoie le même texte.
class _AdContactSheet extends ConsumerStatefulWidget {
  const _AdContactSheet({
    required this.teamSlug,
    required this.adSlug,
    required this.sellerName,
  });

  final String teamSlug;
  final String adSlug;
  final String sellerName;

  @override
  ConsumerState<_AdContactSheet> createState() => _AdContactSheetState();
}

class _AdContactSheetState extends ConsumerState<_AdContactSheet> {
  final TextEditingController _controller = TextEditingController();

  bool _sending = false;

  /// Échec courant, déjà mis en mots. Nul tant que rien n'a échoué.
  String? _error;

  int get _length => _controller.text.trim().length;

  bool get _withinBounds =>
      _length >= kAdContactMinLength && _length <= kAdContactMaxLength;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_withinBounds || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref
          .read(adRepositoryProvider)
          .contactSeller(
            teamSlug: widget.teamSlug,
            adSlug: widget.adSlug,
            message: _controller.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(AdContactOutcome.sent);
    } catch (error, stackTrace) {
      if (!mounted) return;
      final ApiError resolved = resolveApiError(error, stackTrace);
      if (resolved.code == 'AD_CONTACT_OPTED_OUT') {
        // Rien à réessayer : l'écran masquera le bouton.
        Navigator.of(context).pop(AdContactOutcome.optedOut);
        return;
      }
      setState(() {
        _sending = false;
        _error = _message(error, resolved);
      });
    }
  }

  /// Le message d'échec, le quota compris.
  ///
  /// Le 429 porte un `Retry-After` en secondes ; l'afficher tel quel («  dans
  /// 2 700 secondes ») serait exact et inutilisable, d'où l'arrondi à la
  /// minute — puis à l'heure.
  String _message(Object error, ApiError resolved) {
    if (resolved.code == 'AD_CONTACT_RATE_LIMITED') {
      final Duration? wait = _retryAfter(error);
      if (wait == null) return 'ads.contact.rateLimited'.tr();
      return 'ads.contact.rateLimitedIn'.tr(
        namedArgs: <String, String>{'delay': _humanDelay(wait)},
      );
    }
    if (resolved.code == 'AD_CONTACT_DELIVERY_FAILED') {
      return 'ads.contact.deliveryFailed'.tr();
    }
    return resolved.message;
  }

  Duration? _retryAfter(Object error) {
    if (error is! DioException) return null;
    final String? header = error.response?.headers.value('retry-after');
    final int? seconds = header == null ? null : int.tryParse(header.trim());
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  String _humanDelay(Duration wait) {
    if (wait.inMinutes < 1) return 'ads.contact.delayUnderMinute'.tr();
    if (wait.inMinutes < 60) {
      return 'ads.contact.delayMinutes'.plural(wait.inMinutes);
    }
    return 'ads.contact.delayHours'.plural((wait.inMinutes / 60).ceil());
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool tooLong = _length > kAdContactMaxLength;

    return PdlSheet(
      title: 'ads.contact.title'.tr(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'ads.contact.intro'.tr(
                  namedArgs: <String, String>{'seller': widget.sellerName},
                ),
                style: t.sub,
              ),
              const SizedBox(height: PdlSpacing.cardTight),
              TextField(
                key: keys.adContact.messageField,
                controller: _controller,
                onChanged: (_) => setState(() {}),
                minLines: 4,
                maxLines: 8,
                enabled: !_sending,
                textCapitalization: TextCapitalization.sentences,
                // Pas de `maxLength` dur : couper la frappe à 2 000 sans rien
                // dire donnerait un champ qui cesse de répondre. Le compteur
                // passe en danger et l'envoi se coupe, ce qui s'explique.
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(kAdContactMaxLength + 200),
                ],
                style: t.body,
                decoration: InputDecoration(
                  hintText: 'ads.contact.placeholder'.tr(),
                  hintStyle: t.body.copyWith(color: c.textPlaceholder),
                  filled: true,
                  fillColor: c.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: PdlRadii.mdAll,
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: PdlRadii.mdAll,
                    borderSide: BorderSide(
                      color: tooLong ? c.danger : c.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: PdlRadii.mdAll,
                    borderSide: BorderSide(
                      color: tooLong ? c.danger : c.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _length < kAdContactMinLength
                          ? 'ads.contact.tooShort'.tr(
                              namedArgs: <String, String>{
                                'min': '$kAdContactMinLength',
                              },
                            )
                          : '',
                      style: t.xs,
                    ),
                  ),
                  Text(
                    '$_length / $kAdContactMaxLength',
                    style: t.xs.copyWith(
                      color: tooLong ? c.dangerOnSoft : c.textDimmed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PdlSpacing.cardTight),
              // **Un consentement, pas une note de bas de page.** L'API ne
              // divulgue aucune adresse ; celle de l'expéditeur part quand
              // même, puisque le serveur y pose le `Reply-To`. Le dire avant
              // l'envoi est la seule façon de le rendre choisi.
              PdlBanner(
                tone: PdlBannerTone.info,
                icon: PdlIcons.email,
                message: 'ads.contact.replyToNotice'.tr(),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.cardTight),
                PdlBanner(
                  key: keys.adContact.error,
                  tone: PdlBannerTone.danger,
                  message: _error!,
                ),
              ],
            ],
          ),
        ),
      ),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.chipGap,
            PdlSpacing.section,
            PdlSpacing.chipGap,
          ),
          child: PdlButton(
            key: keys.adContact.sendButton,
            label: _error == null
                ? 'ads.contact.send'.tr()
                : 'common.retry'.tr(),
            loadingLabel: 'ads.contact.sending'.tr(),
            loading: _sending,
            enabled: _withinBounds,
            fullWidth: true,
            onPressed: _send,
          ),
        ),
      ),
    );
  }
}
