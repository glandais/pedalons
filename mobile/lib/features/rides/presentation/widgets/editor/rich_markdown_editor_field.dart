import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../api/credential_scope.dart';
import '../../../../../api/generated/export.dart';
import '../../../../../api/pedalons_api_client.dart';
import '../../../../../core/material.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/widgets/authenticated_image.dart';
import '../../../../../core/widgets/markdown_content.dart';
import 'markdown_editor_field.dart';

/// L'éditeur riche d'une publication : **l'éditeur Tiptap du site**, embarqué
/// dans une WebView (POC, `assets/editor/`, construit par
/// `pnpm build:mobile-editor` dans `frontend/`).
///
/// Pourquoi pas un éditeur Flutter : le texte est du markdown écrit par le site
/// (sauts de ligne `\`, échappements, tableaux, directives `::asset{}`), et un
/// éditeur à modèle propre le réécrirait à chaque ouverture. Celui-ci prend le
/// schéma et la sérialisation du site (`markdownEditorExtensions`,
/// `AssetNodeBase`) : l'app écrit exactement ce que le site écrit.
///
/// Dans le formulaire, le champ n'est que **le texte rendu**, comme sur la
/// fiche ([MarkdownContent]) ; un toucher ouvre l'éditeur en plein écran. Une
/// WebView éditable au milieu d'une page qui défile se disputait le geste avec
/// elle, et sa barre d'outils, qui ne sert qu'à la frappe, n'avait pas de place
/// stable : en plein écran, la WebView est tout le corps et la barre est en
/// bas, au-dessus du clavier.
///
/// Même contrat que [MarkdownEditorField] : le texte vit dans [controller],
/// que l'éditeur tient à jour à chaque frappe. La page ne connaît ni jeton ni
/// adresse : les images passent par l'app, qui les charge avec ses en-têtes et
/// les lui rend en `data:`.
class RichMarkdownEditorField extends StatefulWidget {
  const RichMarkdownEditorField({
    super.key,
    required this.controller,
    required this.title,
    this.images = const <AssetDto>[],
    this.onInsertImage,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.imageBusy = false,
  });

  final TextEditingController controller;

  /// Le titre de l'éditeur plein écran — celui de la section du formulaire.
  final String title;
  final List<AssetDto> images;
  final Future<String?> Function()? onInsertImage;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final bool imageBusy;

  @override
  State<RichMarkdownEditorField> createState() =>
      _RichMarkdownEditorFieldState();
}

class _RichMarkdownEditorFieldState extends State<RichMarkdownEditorField> {
  // Ce que le formulaire change pendant que l'éditeur est ouvert (une image
  // envoyée, son indicateur) : l'écran plein, route à part, ne se reconstruit
  // pas avec lui et l'écoute ici.
  late final ValueNotifier<List<AssetDto>> _images =
      ValueNotifier<List<AssetDto>>(widget.images);
  late final ValueNotifier<bool> _imageBusy = ValueNotifier<bool>(
    widget.imageBusy,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(RichMarkdownEditorField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    _images.value = widget.images;
    _imageBusy.value = widget.imageBusy;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _images.dispose();
    _imageBusy.dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RichMarkdownEditorScreen(
          title: widget.title,
          controller: widget.controller,
          images: _images,
          imageBusy: _imageBusy,
          onInsertImage: widget.onInsertImage,
          hintText: widget.hintText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String text = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: PdlRadii.mdAll,
            side: BorderSide(
              color: widget.errorText == null ? c.border : c.danger,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.enabled ? _open : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: PdlMetrics.media120),
              child: Padding(
                padding: const EdgeInsets.all(PdlSpacing.cardTight),
                child: text.trim().isEmpty
                    ? Text(
                        widget.hintText ?? '',
                        style: t.body.copyWith(color: c.textDimmed),
                      )
                    // Le rendu ne réagit pas aux touchers (un lien, une
                    // image) : le champ entier ouvre l'éditeur.
                    : IgnorePointer(
                        child: MarkdownContent(
                          data: text,
                          images: widget.images,
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: PdlSpacing.badgeGap),
            child: Text(
              widget.errorText!,
              style: t.sub.copyWith(color: c.danger),
            ),
          ),
      ],
    );
  }
}

/// L'éditeur en plein écran : le titre et le retour, la WebView, la barre
/// d'outils en bas — au-dessus du clavier quand il est ouvert.
class _RichMarkdownEditorScreen extends ConsumerStatefulWidget {
  const _RichMarkdownEditorScreen({
    required this.title,
    required this.controller,
    required this.images,
    required this.imageBusy,
    this.onInsertImage,
    this.hintText,
  });

  final String title;
  final TextEditingController controller;
  final ValueListenable<List<AssetDto>> images;
  final ValueListenable<bool> imageBusy;
  final Future<String?> Function()? onInsertImage;
  final String? hintText;

  @override
  ConsumerState<_RichMarkdownEditorScreen> createState() =>
      _RichMarkdownEditorScreenState();
}

class _RichMarkdownEditorScreenState
    extends ConsumerState<_RichMarkdownEditorScreen> {
  late final WebViewController _web;
  final Dio _imageClient = Dio();
  bool _ready = false;
  Map<String, bool> _active = const <String, bool>{};

  static const MethodChannel _editorChannel = MethodChannel(
    'fr.pedalons.mobile/rich_editor',
  );

  @override
  void initState() {
    super.initState();
    widget.images.addListener(_onImages);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'PedalonsBridge',
        onMessageReceived: (JavaScriptMessage m) => _onMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _onReady(),
          // Un lien du texte ne navigue pas dans l'éditeur.
          onNavigationRequest: (NavigationRequest r) =>
              r.url.startsWith('file:') || r.url.startsWith('about:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadFlutterAsset('assets/editor/index.html');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _web.setBackgroundColor(context.pdl.surface);
  }

  @override
  void dispose() {
    widget.images.removeListener(_onImages);
    _imageClient.close();
    super.dispose();
  }

  Future<void> _js(String source) => _web.runJavaScript(source);

  List<Map<String, String?>> _assetRefs() => <Map<String, String?>>[
    for (final AssetDto a in widget.images.value)
      <String, String?>{'id': a.id, 'imageUrl': a.imageUrl, 'url': a.url},
  ];

  void _onImages() {
    if (_ready) _js('pedalons.setImages(${jsonEncode(_assetRefs())})');
  }

  /// Le texte, les images et le thème, puis le curseur à la fin du texte et le
  /// clavier ouvert : on ouvre l'éditeur pour écrire.
  Future<void> _onReady() async {
    if (_ready || !mounted) return;
    _ready = true;
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    String css(Color color) {
      final int argb = color.toARGB32();
      return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    }

    final Map<String, Object> theme = <String, Object>{
      'text': css(c.text),
      'muted': css(c.textDimmed),
      'background': css(c.surface),
      'border': css(c.border),
      'accent': css(c.primary),
      'surface': css(c.surfaceAlt),
      'fontSize': t.body.fontSize ?? 15,
    };
    await _js(
      'pedalons.load(${jsonEncode(widget.controller.text)}, '
      '${jsonEncode(_assetRefs())}, ${jsonEncode(widget.hintText ?? '')}, '
      '${jsonEncode(theme)})',
    );
    await _js('pedalons.focusEnd()');
    await _showKeyboard();
  }

  /// Un `focus()` en JavaScript, sans geste de la personne, n'ouvre pas le
  /// clavier : Android le demande pour la WebView
  /// (`MainActivity.showEditorKeyboard`). Rien sur iOS pour l'instant.
  Future<void> _showKeyboard() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _editorChannel.invokeMethod<bool>('showKeyboard');
    } on PlatformException {
      // Le clavier reste fermé : un toucher dans le texte l'ouvre.
    }
  }

  Future<void> _onMessage(String raw) async {
    final Map<String, dynamic> msg = jsonDecode(raw) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'ready':
        await _onReady();
      case 'change':
        widget.controller.text = msg['markdown'] as String;
      case 'state':
        if (!mounted) return;
        setState(() => _active = (msg['active'] as Map).cast<String, bool>());
      case 'image':
        await _sendImage(msg['key'] as String, msg['url'] as String);
    }
  }

  /// Charge une image avec les en-têtes de l'app — ceux d'[AuthenticatedImage],
  /// pour l'origine de l'API seulement — et la passe à la page.
  Future<void> _sendImage(String key, String url) async {
    final String resolved = resolveImageUrl(url);
    final String? token = ref.read(accessTokenHolderProvider);
    try {
      final Response<List<int>> res = await _imageClient.get<List<int>>(
        resolved,
        options: Options(
          responseType: ResponseType.bytes,
          headers: authHeadersFor(resolved, token),
        ),
      );
      final String type =
          res.headers.value(Headers.contentTypeHeader) ?? 'image/jpeg';
      final String dataUrl = 'data:$type;base64,${base64Encode(res.data!)}';
      if (!mounted) return;
      await _js('pedalons.image(${jsonEncode(key)}, ${jsonEncode(dataUrl)})');
    } on DioException {
      // L'image reste vide dans l'éditeur ; le texte, lui, garde sa directive.
    }
  }

  void _cmd(String name) => _js('pedalons.cmd(${jsonEncode(name)})');

  Future<void> _link() async {
    final ({String url, String label})? link = await askMarkdownLink(context);
    if (link == null || !mounted) return;
    await _js(
      'pedalons.setLink(${jsonEncode(link.url)}, ${jsonEncode(link.label)})',
    );
  }

  Future<void> _image() async {
    final Future<String?> Function()? insert = widget.onInsertImage;
    if (insert == null) return;
    final String? directive = await insert();
    if (directive == null || !mounted) return;
    // La nouvelle image n'arrive dans [widget.images] qu'au prochain build du
    // formulaire : la page la redemande à `setImages` ([_onImages]).
    await _js('pedalons.insertDirective(${jsonEncode(directive)})');
    // Le sélecteur de photos a fermé le clavier.
    await _showKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    Widget tool(
      IconData icon,
      String labelKey,
      VoidCallback onTap, {
      String? state,
    }) {
      final bool on = state != null && (_active[state] ?? false);
      return IconButton(
        icon: Icon(icon, size: 22),
        color: on ? c.primary : c.text,
        isSelected: on,
        tooltip: labelKey.tr(),
        constraints: const BoxConstraints(
          minWidth: PdlMetrics.tapTarget,
          minHeight: PdlMetrics.tapTarget,
        ),
        onPressed: onTap,
      );
    }

    final Widget toolbar = Material(
      color: c.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: PdlSpacing.badgeGap),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  tool(
                    PdlIcons.formatBold,
                    'rides.editor.toolbar.bold',
                    () => _cmd('bold'),
                    state: 'bold',
                  ),
                  tool(
                    PdlIcons.formatItalic,
                    'rides.editor.toolbar.italic',
                    () => _cmd('italic'),
                    state: 'italic',
                  ),
                  tool(
                    PdlIcons.formatHeading,
                    'rides.editor.toolbar.heading',
                    () => _cmd('heading'),
                    state: 'heading',
                  ),
                  if (widget.onInsertImage != null)
                    ValueListenableBuilder<bool>(
                      valueListenable: widget.imageBusy,
                      builder: (_, bool busy, _) => busy
                          ? const SizedBox(
                              width: PdlMetrics.tapTarget,
                              height: PdlMetrics.tapTarget,
                              child: Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                            )
                          : tool(
                              PdlIcons.imageAdd,
                              'rides.editor.toolbar.image',
                              _image,
                            ),
                    ),
                  tool(
                    PdlIcons.formatBullets,
                    'rides.editor.toolbar.bullets',
                    () => _cmd('bulletList'),
                    state: 'bulletList',
                  ),
                  tool(
                    PdlIcons.formatNumbers,
                    'rides.editor.toolbar.numbers',
                    () => _cmd('orderedList'),
                    state: 'orderedList',
                  ),
                  tool(
                    PdlIcons.formatQuote,
                    'rides.editor.toolbar.quote',
                    () => _cmd('blockquote'),
                    state: 'blockquote',
                  ),
                  tool(
                    PdlIcons.link,
                    'rides.editor.toolbar.link',
                    _link,
                    state: 'link',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return PdlScreenScaffold(
      backgroundColor: c.surface,
      appBar: PdlAppBar(
        title: widget.title,
        onBack: () => Navigator.of(context).maybePop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      actionBar: toolbar,
      body: WebViewWidget(
        controller: _web,
        // Rien d'autre ne défile à l'écran : la WebView prend tous les gestes.
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
        },
      ),
    );
  }
}
