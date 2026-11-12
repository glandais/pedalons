import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/logging/client_context.dart';
import '../../../core/material.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../../core/theme/pdl_typography.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../../keys.dart';
import '../data/feedback_repository.dart';

/// Bornes du message, imposées par `FeedbackRequest` au contrat. Un bug peut
/// partir sans message — qui tombe sur une erreur ne sait pas forcément ce qui
/// s'est passé, le contexte et le journal parlent pour lui ; une suggestion,
/// jamais.
const int kFeedbackMinLength = 10;
const int kFeedbackMaxLength = 5000;

/// Ouvre « Signaler un problème ». [error], quand il est donné, est l'erreur
/// d'où le membre part : elle est jointe au signalement, ce qui le relie au
/// rapport automatique de la même erreur.
///
/// Rend `true` quand le signalement est parti ; le remerciement s'affiche
/// alors ici, pour que chaque point d'entrée n'ait pas à le redire.
Future<bool> showFeedbackSheet(
  BuildContext context, {
  ClientErrorDto? error,
}) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final bool? sent = await PdlSheet.show<bool>(
    context: context,
    builder: (BuildContext sheetContext) => FeedbackSheet(error: error),
  );
  if (sent == true) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(key: keys.feedback.sentMessage, 'feedback.sent'.tr()),
      ),
    );
  }
  return sent == true;
}

/// La feuille de signalement.
///
/// **Ce qui part est ce qui est montré.** Le contexte et le journal sont
/// photographiés à l'ouverture de la feuille, et l'aperçu dépliable rend cette
/// photographie-là, ligne à ligne : ce qui s'écrit au journal pendant que le
/// membre tape (sa propre saisie ne s'y écrit pas, mais une requête en fond
/// si) ne s'ajoute pas en douce.
///
/// **Le brouillon survit à l'échec** — quota, serveur en panne, hors ligne —
/// comme dans la feuille de contact d'une annonce : le champ n'est ni vidé ni
/// fermé, et « Réessayer » renvoie le même texte.
class FeedbackSheet extends ConsumerStatefulWidget {
  const FeedbackSheet({super.key, this.error});

  final ClientErrorDto? error;

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final TextEditingController _controller = TextEditingController();

  FeedbackKind _kind = FeedbackKind.bug;
  bool _attach = true;
  bool _showPreview = false;
  bool _sending = false;
  String? _error;

  late final ClientContextDto _context;
  late final ClientContextDto _minimalContext;
  late final List<ClientLogEntryDto> _logs;

  @override
  void initState() {
    super.initState();
    final ClientContextBuilder builder = ref.read(clientContextBuilderProvider);
    _context = builder.build();
    _minimalContext = builder.buildMinimal();
    _logs = ref.read(appLogProvider).snapshot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _length => _controller.text.trim().length;

  bool get _messageOptional => _kind == FeedbackKind.bug;

  bool get _withinBounds =>
      (_length == 0 && _messageOptional) ||
      (_length >= kFeedbackMinLength && _length <= kFeedbackMaxLength);

  FeedbackRequest _request() => FeedbackRequest(
    kind: _kind.toJson(),
    message: _length == 0 ? null : _controller.text.trim(),
    context: _attach ? _context : _minimalContext,
    error: _attach ? widget.error : null,
    logs: _attach ? _logs : null,
  );

  Future<void> _send() async {
    if (!_withinBounds || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(feedbackRepositoryProvider).send(_request());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _message(error, resolveApiError(error, stackTrace));
      });
    }
  }

  /// Le message d'échec. Le 429 porte un `Retry-After` en secondes, arrondi
  /// à la minute puis à l'heure — même lecture que la feuille de contact.
  String _message(Object error, ApiError resolved) {
    if (resolved.code == ErrorCode.feedbackRateLimited.json) {
      final Duration? wait = _retryAfter(error);
      if (wait == null) return 'feedback.rateLimited'.tr();
      return 'feedback.rateLimitedIn'.tr(
        namedArgs: <String, String>{'delay': _humanDelay(wait)},
      );
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
    if (wait.inMinutes < 1) return 'feedback.delayUnderMinute'.tr();
    if (wait.inMinutes < 60) {
      return 'feedback.delayMinutes'.plural(wait.inMinutes);
    }
    return 'feedback.delayHours'.plural((wait.inMinutes / 60).ceil());
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool tooLong = _length > kFeedbackMaxLength;
    final ClientErrorDto? attachedError = widget.error;

    return PdlSheet(
      title: 'feedback.title'.tr(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PdlSegmented<FeedbackKind>(
                value: _kind,
                onChanged: (FeedbackKind value) =>
                    setState(() => _kind = value),
                segments: <PdlSegment<FeedbackKind>>[
                  PdlSegment<FeedbackKind>(
                    key: keys.feedback.kind(FeedbackKind.bug),
                    value: FeedbackKind.bug,
                    label: 'feedback.kind.bug'.tr(),
                  ),
                  PdlSegment<FeedbackKind>(
                    key: keys.feedback.kind(FeedbackKind.suggestion),
                    value: FeedbackKind.suggestion,
                    label: 'feedback.kind.suggestion'.tr(),
                  ),
                ],
              ),
              const SizedBox(height: PdlSpacing.cardTight),
              if (attachedError != null) ...<Widget>[
                PdlBanner(
                  tone: PdlBannerTone.info,
                  icon: PdlIcons.error,
                  title: 'feedback.errorAttached'.tr(),
                  message: attachedError.message,
                ),
                const SizedBox(height: PdlSpacing.cardTight),
              ],
              TextField(
                key: keys.feedback.messageField,
                controller: _controller,
                onChanged: (_) => setState(() {}),
                minLines: 4,
                maxLines: 8,
                enabled: !_sending,
                textCapitalization: TextCapitalization.sentences,
                // Pas de `maxLength` dur, comme la feuille de contact : le
                // compteur passe en danger et l'envoi se coupe.
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(kFeedbackMaxLength + 200),
                ],
                style: t.body,
                decoration: InputDecoration(
                  hintText: _kind == FeedbackKind.suggestion
                      ? 'feedback.placeholderSuggestion'.tr()
                      : 'feedback.placeholderBug'.tr(),
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
                      _length < kFeedbackMinLength &&
                              (_length > 0 || !_messageOptional)
                          ? 'feedback.tooShort'.tr(
                              namedArgs: <String, String>{
                                'min': '$kFeedbackMinLength',
                              },
                            )
                          : '',
                      style: t.xs,
                    ),
                  ),
                  Text(
                    '$_length / $kFeedbackMaxLength',
                    style: t.xs.copyWith(
                      color: tooLong ? c.dangerOnSoft : c.textDimmed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PdlSpacing.chipGap),
              CheckboxListTile(
                value: _attach,
                onChanged: _sending
                    ? null
                    : (bool? value) => setState(() => _attach = value ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text('feedback.attach'.tr(), style: t.body),
                subtitle: Text(
                  _attach
                      ? 'feedback.attachHint'.tr()
                      : 'feedback.attachOffHint'.tr(),
                  style: t.xs,
                ),
              ),
              if (_attach) ...<Widget>[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PdlButton(
                    label: _showPreview
                        ? 'feedback.hidePreview'.tr()
                        : 'feedback.showPreview'.tr(),
                    icon: _showPreview
                        ? PdlIcons.chevronUp
                        : PdlIcons.chevronDown,
                    variant: PdlButtonVariant.text,
                    size: PdlButtonSize.sm,
                    onPressed: () =>
                        setState(() => _showPreview = !_showPreview),
                  ),
                ),
                if (_showPreview) _Preview(text: _previewText()),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.cardTight),
                PdlBanner(tone: PdlBannerTone.danger, message: _error!),
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
            key: keys.feedback.sendButton,
            label: _error == null ? 'feedback.send'.tr() : 'common.retry'.tr(),
            loadingLabel: 'feedback.sending'.tr(),
            loading: _sending,
            enabled: _withinBounds,
            fullWidth: true,
            onPressed: _send,
          ),
        ),
      ),
    );
  }

  /// Exactement ce qui part en plus du message : le contexte champ par champ,
  /// l'erreur, puis le journal.
  String _previewText() {
    final StringBuffer out = StringBuffer();
    _context.toJson().forEach((String key, Object? value) {
      if (value != null) out.writeln('$key: $value');
    });
    final ClientErrorDto? error = widget.error;
    if (error != null) {
      out
        ..writeln()
        ..writeln('error: ${error.type}: ${error.message}');
      if (error.stack != null) out.writeln(error.stack);
    }
    out
      ..writeln()
      ..writeln('logs: ${_logs.length}');
    for (final ClientLogEntryDto e in _logs) {
      out.writeln('${e.ts} ${e.level} [${e.source}] ${e.message}');
    }
    return out.toString().trimRight();
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: PdlRadii.mdAll,
        border: Border.all(color: c.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PdlSpacing.chipGap),
        child: SelectableText(text, style: t.mono.copyWith(color: c.text)),
      ),
    );
  }
}
