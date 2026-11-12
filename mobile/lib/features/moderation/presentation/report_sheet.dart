import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../core/material.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../../core/theme/pdl_typography.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../../keys.dart';
import '../data/moderation_repository.dart';

/// Borne du texte libre, imposée par `ReportRequest` au contrat.
const int kReportMessageMaxLength = 500;

/// Ce que l'on signale : une cible, **dans une équipe** — c'est l'équipe qui
/// décide qui modère.
@immutable
class ModerationSubject {
  const ModerationSubject({
    required this.teamSlug,
    required this.type,
    required this.id,
    this.teamName,
    this.memberName,
  });

  final String teamSlug;
  final ReportTargetType type;

  /// Identifiant du contenu, ou de l'utilisateur pour un membre.
  final String id;

  /// Nommé dans la phrase « Transmis aux organisateurs de … ». Un commentaire
  /// ne le connaît pas toujours : la phrase dit alors « de l'équipe ».
  final String? teamName;

  /// Le nom du membre signalé, pour le titre de la feuille.
  final String? memberName;
}

/// Ouvre la feuille de signalement. `true` une fois le signalement accepté.
Future<bool> showReportSheet(
  BuildContext context, {
  required ModerationSubject subject,
}) async {
  final bool? sent = await PdlSheet.show<bool>(
    context: context,
    builder: (BuildContext _) => _ReportSheet(subject: subject),
  );
  return sent ?? false;
}

/// Motif, texte libre, Envoyer.
///
/// **Aucun succès optimiste**, comme la feuille de contact d'une annonce : le
/// bouton reste en cours tant que le serveur n'a pas répondu, et un échec est
/// rendu dans la feuille, motif et texte conservés.
class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.subject});

  final ModerationSubject subject;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final TextEditingController _message = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  String? _error;

  ModerationSubject get _subject => widget.subject;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ReportReason? reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(moderationRepositoryProvider)
          .report(
            teamSlug: _subject.teamSlug,
            targetType: _subject.type,
            targetId: _subject.id,
            reason: reason,
            message: _message.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  String get _title => 'moderation.reportTitle.${_subject.type.toJson()}'.tr(
    namedArgs: <String, String>{'name': _subject.memberName ?? ''},
  );

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String? teamName = _subject.teamName;

    return PdlSheet(
      title: _title,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PdlSpacing.section,
              ),
              child: Text('moderation.reasonPrompt'.tr(), style: t.sub),
            ),
            // Un choix exclusif qui se valide au pied de la feuille : la
            // coche indigo des feuilles de choix, pas des boutons radio.
            for (final ReportReason reason in ReportReason.$valuesDefined)
              PdlSettingRow(
                key: keys.moderation.reason(reason),
                title: 'moderation.reason.${reason.toJson()}'.tr(),
                trailing: reason == _reason
                    ? Icon(PdlIcons.check, size: 20, color: c.primary)
                    : const SizedBox.shrink(),
                onTap: _sending ? null : () => setState(() => _reason = reason),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                PdlSpacing.chipGap,
                PdlSpacing.section,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: _message,
                    minLines: 2,
                    maxLines: 5,
                    enabled: !_sending,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(kReportMessageMaxLength),
                    ],
                    style: t.body,
                    decoration: InputDecoration(
                      hintText: 'moderation.messageHint'.tr(),
                      hintStyle: t.body.copyWith(color: c.textPlaceholder),
                      filled: true,
                      fillColor: c.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: PdlRadii.mdAll,
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: PdlRadii.mdAll,
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: PdlRadii.mdAll,
                        borderSide: BorderSide(color: c.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: PdlSpacing.cardTight),
                  // Qui lira : les organisateurs de l'équipe et Pédalons.
                  // Jamais la personne signalée, qui n'est pas destinataire.
                  Text(
                    teamName == null
                        ? 'moderation.recipientsNoTeam'.tr()
                        : 'moderation.recipients'.tr(
                            namedArgs: <String, String>{'team': teamName},
                          ),
                    style: t.xs,
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: PdlSpacing.cardTight),
                    PdlBanner(tone: PdlBannerTone.danger, message: _error!),
                  ],
                ],
              ),
            ),
          ],
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
            key: keys.moderation.sendReportButton,
            label: _error == null
                ? 'moderation.send'.tr()
                : 'common.retry'.tr(),
            loadingLabel: 'moderation.sending'.tr(),
            loading: _sending,
            enabled: _reason != null,
            fullWidth: true,
            onPressed: _send,
          ),
        ),
      ),
    );
  }
}
