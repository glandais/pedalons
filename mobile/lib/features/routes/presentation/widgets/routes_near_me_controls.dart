import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/geo/location_banner.dart';
import '../../../../core/geo/location_service.dart';
import '../../../../core/geo/polyline_index.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/route_filters.dart';

/// « Autour de moi » : la pastille d'état et les trois rayons.
///
/// Le groupe est posé sur la carte, donc **toujours sur une surface opaque** :
/// `PdlMapPill` et `PdlChip` sur `overlaySolid`, jamais du texte à même la
/// tuile.
///
/// La proximité vit dans [RouteFilters], pas ici : changer de rayon recharge
/// donc **la liste et la carte** d'un seul mouvement, puisque les deux vues
/// lisent le même jeu de filtres.
///
/// L'échec de localisation ne bloque rien. Un refus définitif rend un
/// [LocationFailureBanner] avec « Ouvrir les réglages » — **jamais** un
/// dialogue système redemandé, que iOS n'affiche de toute façon plus.
class RoutesNearMeControls extends ConsumerStatefulWidget {
  const RoutesNearMeControls({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  final RouteFilters filters;
  final ValueChanged<RouteFilters> onChanged;

  @override
  ConsumerState<RoutesNearMeControls> createState() =>
      _RoutesNearMeControlsState();
}

class _RoutesNearMeControlsState extends ConsumerState<RoutesNearMeControls> {
  LocationFailure? _failure;
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    final bool armed = widget.filters.hasProximity;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PdlMapPill(
          icon: _locating ? PdlIcons.refresh : PdlIcons.nearMe,
          label: _locating
              ? 'routes.nearMe.locating'.tr()
              : (armed
                    ? 'routes.nearMe.active'.tr(
                        namedArgs: <String, String>{
                          'radius': AppFormatters.formatDistanceRounded(
                            widget.filters.effectiveNearRadius,
                            units,
                          ),
                        },
                      )
                    : 'routes.nearMe.title'.tr()),
          onPressed: _locating ? null : (armed ? _disarm : _locate),
        ),
        if (armed) ...<Widget>[
          const SizedBox(height: 4),
          PdlChipRow(
            padding: EdgeInsets.zero,
            fadeWidth: 0,
            children: <Widget>[
              for (final double radius in kRouteNearRadiiMeters)
                PdlChip(
                  label: AppFormatters.formatDistanceRounded(radius, units),
                  selected: widget.filters.effectiveNearRadius == radius,
                  onTap: () => widget.onChanged(
                    widget.filters.copyWith(nearRadius: radius),
                  ),
                ),
            ],
          ),
        ],
        if (_failure != null) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          LocationFailureBanner(
            failure: _failure!,
            service: ref.read(locationServiceProvider),
            onRetry: _locate,
            onDismiss: () => setState(() => _failure = null),
          ),
        ],
      ],
    );
  }

  void _disarm() {
    setState(() => _failure = null);
    widget.onChanged(widget.filters.without(RouteFilterField.proximity));
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _failure = null;
    });
    final LocationResult result = await ref
        .read(locationServiceProvider)
        .requestCoarsePosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _failure = result.failure;
    });
    final LngLat? position = result.position;
    if (position == null) return;
    widget.onChanged(
      widget.filters.copyWith(
        nearLat: position.lat,
        nearLon: position.lng,
        nearRadius: widget.filters.nearRadius ?? kDefaultRouteNearRadiusMeters,
      ),
    );
  }
}
