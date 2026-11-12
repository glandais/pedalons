import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../domain/comment_links.dart';

/// Le texte d'un commentaire, tel qu'il a été tapé (règle R12, KIT §9) :
/// pas de Markdown, retours à la ligne gardés. Seule une adresse complète
/// (`http://`, `https://`) devient un lien, affiché en entier et ouvert par
/// [openLink] — le même chemin que les liens d'une description (décision du
/// 2026-11-12).
class CommentText extends StatefulWidget {
  const CommentText(
    this.content, {
    super.key,
    this.textKey,
    required this.style,
  });

  final String content;

  /// La clé du `Text` rendu — celle que les tests lisent
  /// (`keys.comments.content`), sur le texte lui-même.
  final Key? textKey;
  final TextStyle style;

  @override
  State<CommentText> createState() => _CommentTextState();
}

class _CommentTextState extends State<CommentText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final TapGestureRecognizer r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<CommentSegment> segments = splitCommentLinks(widget.content);
    if (!segments.any((CommentSegment s) => s.isLink)) {
      return Text(widget.content, key: widget.textKey, style: widget.style);
    }
    _disposeRecognizers();
    final PdlColors c = context.pdl;
    final TextStyle linkStyle = widget.style.copyWith(
      color: c.link,
      decoration: TextDecoration.underline,
      decorationColor: c.link,
    );
    return Text.rich(
      key: widget.textKey,
      TextSpan(
        style: widget.style,
        children: <InlineSpan>[
          for (final CommentSegment s in segments)
            if (s.isLink)
              TextSpan(
                text: s.text,
                style: linkStyle,
                recognizer: _recognizer(s.text),
              )
            else
              TextSpan(text: s.text),
        ],
      ),
    );
  }

  TapGestureRecognizer _recognizer(String url) {
    final TapGestureRecognizer r = TapGestureRecognizer()
      ..onTap = () => unawaited(openLink(context, url));
    _recognizers.add(r);
    return r;
  }
}
