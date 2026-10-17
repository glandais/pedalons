import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/utils/api_error_handler.dart';
import '../../../../../keys.dart';

/// Une page de résultats d'un sélecteur : les éléments et le total serveur,
/// qui dit s'il reste quelque chose à charger (pagination par décalage,
/// ledger `API-21`).
typedef PickerPage<T> = ({List<T> items, int total});

typedef PickerLoader<T> =
    Future<PickerPage<T>> Function(String? search, int page);

/// Ouvre une feuille plein rideau de choix dans une liste serveur, avec
/// recherche et chargement à la demande — parcours, lieux, membres, modèles
/// de l'éditeur de sortie (ledger `MOB-76`). Rend l'élément choisi, ou `null`
/// si la feuille a été fermée.
Future<T?> showSearchPickerSheet<T>(
  BuildContext context, {
  required String title,
  required String searchHint,
  required String emptyMessage,
  required PickerLoader<T> load,
  required String Function(T item) idOf,
  required Widget Function(BuildContext context, T item, VoidCallback onTap)
  itemBuilder,
}) {
  return PdlFullSheet.show<T>(
    context: context,
    builder: (BuildContext _) => SearchPickerSheet<T>(
      title: title,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
      load: load,
      idOf: idOf,
      itemBuilder: itemBuilder,
    ),
  );
}

class SearchPickerSheet<T> extends StatefulWidget {
  const SearchPickerSheet({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    required this.load,
    required this.idOf,
    required this.itemBuilder,
  });

  final String title;
  final String searchHint;
  final String emptyMessage;
  final PickerLoader<T> load;
  final String Function(T item) idOf;
  final Widget Function(BuildContext context, T item, VoidCallback onTap)
  itemBuilder;

  @override
  State<SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<SearchPickerSheet<T>> {
  final List<T> _items = <T>[];
  String? _search;
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  Object? _error;

  /// Numéro de la dernière requête : une réponse plus ancienne, arrivée
  /// après une recherche plus récente, est ignorée.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  bool get _hasMore => _items.length < _total;

  void _reload() {
    _items.clear();
    _page = 0;
    _total = 0;
    _fetch();
  }

  Future<void> _fetch() async {
    final int generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final PickerPage<T> page = await widget.load(_search, _page);
      if (!mounted || generation != _generation) return;
      setState(() {
        // Dédoublonné par id : une insertion côté serveur entre deux pages
        // décale le décalage d'un cran.
        final Set<String> seen = <String>{
          for (final T i in _items) widget.idOf(i),
        };
        _items.addAll(page.items.where((T i) => seen.add(widget.idOf(i))));
        _total = page.total;
        _page++;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PdlFullSheet(
      title: widget.title,
      headerAction: PdlButton(
        label: 'common.cancel'.tr(),
        variant: PdlButtonVariant.text,
        size: PdlButtonSize.sm,
        onPressed: () => Navigator.of(context).pop(),
      ),
      bodyBuilder: (BuildContext context, ScrollController controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                0,
                PdlSpacing.section,
                PdlSpacing.chipGap,
              ),
              child: PdlSearchField(
                key: keys.rideEditor.pickerSearch,
                value: _search,
                hintText: widget.searchHint,
                clearTooltip: 'common.clearSearch'.tr(),
                onChanged: (String? value) {
                  _search = value;
                  _reload();
                },
              ),
            ),
            Expanded(child: _list(context, controller)),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, ScrollController controller) {
    if (_items.isEmpty) {
      if (_error != null) {
        return ListView(
          controller: controller,
          children: <Widget>[
            PdlEmptyState(
              variant: PdlEmptyVariant.error,
              title: 'common.loadError'.tr(),
              message: getErrorMessage(_error!),
              actions: <Widget>[
                PdlButton(label: 'common.retry'.tr(), onPressed: _fetch),
              ],
            ),
          ],
        );
      }
      if (_loading) {
        return ListView(
          controller: controller,
          children: const <Widget>[
            Padding(
              padding: EdgeInsets.all(PdlSpacing.section),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ],
        );
      }
      return ListView(
        controller: controller,
        children: <Widget>[
          PdlEmptyState(
            variant: (_search ?? '').isEmpty
                ? PdlEmptyVariant.empty
                : PdlEmptyVariant.filtered,
            title: widget.emptyMessage,
          ),
        ],
      );
    }
    return ListView.builder(
      controller: controller,
      itemCount: _items.length + (_hasMore || _error != null ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index >= _items.length) {
          // La ligne de fin déclenche la page suivante en apparaissant.
          if (_error == null && !_loading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_loading && _hasMore) _fetch();
            });
          }
          return Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: Center(
              child: _error != null
                  ? PdlButton(
                      label: 'common.retry'.tr(),
                      variant: PdlButtonVariant.outline,
                      size: PdlButtonSize.sm,
                      onPressed: _fetch,
                    )
                  : const CircularProgressIndicator.adaptive(),
            ),
          );
        }
        final T item = _items[index];
        return KeyedSubtree(
          key: keys.rideEditor.pickerOption(widget.idOf(item)),
          child: widget.itemBuilder(
            context,
            item,
            () => Navigator.of(context).pop(item),
          ),
        );
      },
    );
  }
}
