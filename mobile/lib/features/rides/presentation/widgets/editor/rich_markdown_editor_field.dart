import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../api/credential_scope.dart';
import '../../../../../api/generated/export.dart';
import '../../../../../api/pedalons_api_client.dart';
import '../../../../../core/material.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/widgets/authenticated_image.dart';
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
/// Même contrat que [MarkdownEditorField] : le texte vit dans [controller],
/// que l'éditeur tient à jour à chaque frappe et relit quand il change ailleurs
/// (une image ajoutée depuis la section Médias). La page ne connaît ni jeton ni
/// adresse : les images passent par l'app, qui les charge avec ses en-têtes et
/// les lui rend en `data:`.
class RichMarkdownEditorField extends ConsumerStatefulWidget {
  const RichMarkdownEditorField({
    super.key,
    required this.controller,
    this.images = const <AssetDto>[],
    this.onInsertImage,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.imageBusy = false,
    this.height = 360,
    this.onTypingChanged,
  });

  final TextEditingController controller;
  final List<AssetDto> images;
  final Future<String?> Function()? onInsertImage;
  final String? hintText;
  final String? errorText;
  final bool enabled;
  final bool imageBusy;

  /// La hauteur de la zone d'édition, qui défile en elle-même. Pendant la
  /// frappe, elle se réduit à ce que le clavier laisse visible.
  final double height;

  /// Appelé quand la frappe commence ou s'arrête (l'éditeur a le focus et le
  /// clavier est ouvert). La barre d'outils est alors posée au-dessus du
  /// clavier, là où l'écran a sa barre d'action : l'écran la retire.
  final ValueChanged<bool>? onTypingChanged;

  @override
  ConsumerState<RichMarkdownEditorField> createState() =>
      _RichMarkdownEditorFieldState();
}

class _RichMarkdownEditorFieldState
    extends ConsumerState<RichMarkdownEditorField>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  final Dio _images = Dio();
  bool _ready = false;
  bool _themed = false;

  /// Le dernier texte échangé avec la page, dans un sens ou dans l'autre : ce
  /// que l'éditeur vient d'écrire ne doit pas lui revenir comme un changement.
  String _synced = '';
  Map<String, bool> _active = const <String, bool>{};

  /// La page a le focus (d'après Tiptap).
  bool _focused = false;

  /// La frappe est en cours : [_focused] et le clavier ouvert. La barre
  /// d'outils quitte alors le haut du champ pour le dessus du clavier — au
  /// haut du champ, le menu Android de la sélection (Copier, Traduire…), qui
  /// se pose au-dessus du texte sélectionné, la recouvrait.
  bool _typing = false;
  double _typingInset = 0;
  final OverlayPortalController _dock = OverlayPortalController();
  final GlobalKey _editorBox = GlobalKey();

  static const double _dockHeight =
      PdlMetrics.tapTarget + 2 * PdlSpacing.badgeGap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _synced = widget.controller.text;
    widget.controller.addListener(_onControllerChanged);
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
    if (_ready) _load();
  }

  @override
  void didUpdateWidget(RichMarkdownEditorField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (!_ready) return;
    if (!listEquals(old.images, widget.images)) {
      _js('pedalons.setImages(${jsonEncode(_assetRefs())})');
    }
    if (old.enabled != widget.enabled) {
      _js('pedalons.setEditable(${widget.enabled})');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    _images.close();
    super.dispose();
  }

  /// Le clavier s'ouvre ou se ferme : voir [_keyboardInset].
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  /// La hauteur du clavier, lue sur la vue : le [Scaffold] de l'écran la
  /// retire du [MediaQuery] de son corps, où le champ la lirait toujours nulle.
  double _keyboardInset() {
    final FlutterView view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  Future<void> _js(String source) => _web.runJavaScript(source);

  List<Map<String, String?>> _assetRefs() => <Map<String, String?>>[
    for (final AssetDto a in widget.images)
      <String, String?>{'id': a.id, 'imageUrl': a.imageUrl, 'url': a.url},
  ];

  void _onReady() {
    if (_ready) return;
    _ready = true;
    _load();
    if (!widget.enabled) _js('pedalons.setEditable(false)');
  }

  /// Le texte, les images et le thème — au chargement, et quand le thème change.
  void _load() {
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
    _themed = true;
    _synced = widget.controller.text;
    _js(
      'pedalons.load(${jsonEncode(_synced)}, ${jsonEncode(_assetRefs())}, '
      '${jsonEncode(widget.hintText ?? 'posts.editor.markdownPlaceholder'.tr())}, '
      '${jsonEncode(theme)})',
    );
  }

  void _onControllerChanged() {
    if (!_ready || !_themed) return;
    final String text = widget.controller.text;
    if (text == _synced) return;
    _synced = text;
    _js(
      'pedalons.load(${jsonEncode(text)}, ${jsonEncode(_assetRefs())}, '
      '${jsonEncode(widget.hintText ?? 'posts.editor.markdownPlaceholder'.tr())}, '
      'null)',
    );
  }

  Future<void> _onMessage(String raw) async {
    final Map<String, dynamic> msg = jsonDecode(raw) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'ready':
        _onReady();
      case 'change':
        final String markdown = msg['markdown'] as String;
        _synced = markdown;
        widget.controller.text = markdown;
      case 'state':
        if (!mounted) return;
        setState(() {
          _active = (msg['active'] as Map).cast<String, bool>();
          _focused = msg['focused'] as bool? ?? false;
        });
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
      final Response<List<int>> res = await _images.get<List<int>>(
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
    // La nouvelle image n'est dans [widget.images] qu'au prochain build : la
    // page la redemande à `setImages`, dans didUpdateWidget.
    await _js('pedalons.insertDirective(${jsonEncode(directive)})');
  }

  /// Suit le passage en frappe et en sort. Appelé pendant build : les effets
  /// (afficher la barre, prévenir l'écran, défiler) attendent la fin du frame.
  void _trackTyping(bool typing, double inset) {
    final bool changed = typing != _typing;
    final bool moved = typing && inset != _typingInset;
    _typing = typing;
    _typingInset = typing ? inset : 0;
    if (!changed && !moved) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (changed) {
        typing ? _dock.show() : _dock.hide();
        widget.onTypingChanged?.call(typing);
      }
      // Le champ entier au-dessus du clavier, son haut en haut de l'écran : sa
      // hauteur est taillée pour que son bas touche la barre d'outils.
      final BuildContext? box = _editorBox.currentContext;
      if (typing && box != null) {
        Scrollable.ensureVisible(box, alignment: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final double inset = _keyboardInset();
    final bool typing = widget.enabled && _focused && inset > 0;
    _trackTyping(typing, inset);

    // Pendant la frappe, le champ tient dans ce que le clavier et la barre
    // d'outils laissent de la page : sinon sa fin, et le curseur qui y est,
    // passent dessous.
    double height = widget.height;
    final ScrollPosition? page = Scrollable.maybeOf(context)?.position;
    if (typing && page != null && page.hasViewportDimension) {
      final double room =
          page.viewportDimension - _dockHeight - PdlSpacing.badgeGap;
      if (room > 120 && room < height) height = room;
    }

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
        onPressed: widget.enabled ? onTap : null,
      );
    }

    final Widget toolbar = SingleChildScrollView(
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
          tool(
            PdlIcons.formatTable,
            'rides.editor.toolbar.table',
            () => _cmd('table'),
          ),
          if (widget.onInsertImage == null)
            const SizedBox.shrink()
          else if (widget.imageBusy)
            const SizedBox(
              width: PdlMetrics.tapTarget,
              height: PdlMetrics.tapTarget,
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else
            tool(PdlIcons.imageAdd, 'rides.editor.toolbar.image', _image),
        ],
      ),
    );

    return OverlayPortal(
      controller: _dock,
      overlayChildBuilder: (BuildContext overlay) => Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.viewInsetsOf(overlay).bottom,
        child: Material(
          color: c.surface,
          child: Container(
            height: _dockHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: toolbar,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!typing) ...<Widget>[
            toolbar,
            const SizedBox(height: PdlSpacing.badgeGap),
          ],
          Container(
            key: _editorBox,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: PdlRadii.mdAll,
              border: Border.all(
                color: widget.errorText == null ? c.border : c.danger,
              ),
            ),
            child: WebViewWidget(
              controller: _web,
              // Glisser verticalement dans le texte le fait défiler, pas la page.
              // Avec le seuil de l'appareil, celui du défileur de la page : avec
              // celui par défaut, plus long, la page gagnait toujours le geste et
              // la WebView ne recevait aucun mouvement.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer()
                    ..gestureSettings = MediaQuery.maybeGestureSettingsOf(
                      context,
                    ),
                ),
              },
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
      ),
    );
  }
}
