// Galerie de composants `core/pdl` — page de DEBUG.
//
// Elle n'est **pas** enregistrée dans le `GoRouter` : elle n'a rien à faire
// dans une app livrée, et une route de production coûterait un chemin public
// et une entrée de deeplink. Pour l'ouvrir, poussez-la depuis n'importe où :
//
// ```dart
// Navigator.of(context).push(
//   MaterialPageRoute<void>(builder: (_) => const PdlGalleryPage()),
// );
// ```
//
// Le plus court en développement est de remplacer temporairement le `home` de
// `PedalonsApp`, ou d'ajouter le push ci-dessus derrière un appui long sur le
// logotype. La page porte sa propre bascule clair / sombre : elle applique le
// thème avec `Theme(data: PedalonsTheme.build(brightness))`, ce qui permet de
// vérifier les deux modes sans toucher aux préférences de l'app.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/pdl/pdl.dart';
import '../core/utils/link_launcher.dart';
import '../core/theme/enum_colors.dart' show PdlTone;
import '../core/theme/pdl_colors.dart';
import '../core/theme/pdl_icons.dart';
import '../core/theme/pdl_tokens.dart';
import '../core/theme/pdl_typography.dart';
import '../core/theme/pedalons_theme.dart';
import 'pdl_shell_demo_page.dart';

/// Galerie des 20 primitives, des 26 composés et des 10 coquilles, dans leurs
/// variantes, en clair et en sombre.
class PdlGalleryPage extends StatefulWidget {
  const PdlGalleryPage({super.key});

  @override
  State<PdlGalleryPage> createState() => _PdlGalleryPageState();
}

class _PdlGalleryPageState extends State<PdlGalleryPage> {
  Brightness _brightness = Brightness.light;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = PedalonsTheme.build(_brightness);
    return Theme(
      data: theme,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: context.pdl.bg,
          appBar: AppBar(
            title: const Text('Galerie core/pdl'),
            // La bascule vit dans le `bottom` et non dans les `actions` :
            // `PdlSegmented` répartit ses positions avec `Expanded`, il lui
            // faut donc une largeur bornée — ce que la rangée d'actions d'une
            // `AppBar`, de largeur libre, ne fournit pas.
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PdlSpacing.section,
                  0,
                  PdlSpacing.section,
                  9,
                ),
                child: PdlSegmented<Brightness>(
                  segments: const <PdlSegment<Brightness>>[
                    PdlSegment<Brightness>(
                      value: Brightness.light,
                      label: 'Clair',
                    ),
                    PdlSegment<Brightness>(
                      value: Brightness.dark,
                      label: 'Sombre',
                    ),
                  ],
                  value: _brightness,
                  onChanged: (Brightness b) => setState(() => _brightness = b),
                ),
              ),
            ),
          ),
          body: const _GalleryBody(),
        ),
      ),
    );
  }
}

class _GalleryBody extends StatefulWidget {
  const _GalleryBody();

  @override
  State<_GalleryBody> createState() => _GalleryBodyState();
}

class _GalleryBodyState extends State<_GalleryBody> {
  bool _switchOn = true;
  bool _switchOff = false;
  String _segment = 'mois';
  String? _search;
  bool _chipSelected = true;

  // ── État des composés de la vague B ─────────────────────────────────────
  RangeValues _range = const RangeValues(20, 90);
  int _dotIndex = 1;

  // ── État des coquilles de la vague C ────────────────────────────────────
  int _tab = 1;
  int _stage = 2;
  DateTime? _selectedDay;
  static final DateTime _demoToday = DateTime(2026, 7, 22);

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    PdlTone tone(Color fill, PdlSoftPair pair) =>
        PdlTone(fill: fill, soft: pair.background, onSoft: pair.foreground);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: PdlSpacing.section),
      children: <Widget>[
        // ── A1 ────────────────────────────────────────────────────────────
        _Block(
          title: 'A1 · PdlSkeleton',
          children: <Widget>[
            const PdlSkeleton(width: double.infinity, height: 120),
            const SizedBox(height: 8),
            Row(
              children: const <Widget>[
                PdlSkeleton.circle(size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      PdlSkeleton.text(width: 160, height: 16),
                      SizedBox(height: 8),
                      PdlSkeleton.text(width: 100),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── A2 ────────────────────────────────────────────────────────────
        _Block(
          title: 'A2 · PdlBadge',
          children: <Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                PdlBadge(label: 'Sortie', tone: tone(c.accentBlue, c.softBlue)),
                PdlBadge(
                  label: 'Publication',
                  tone: tone(c.accentGrape, c.softGrape),
                ),
                PdlBadge(label: 'Voyage', tone: tone(c.accentTeal, c.softTeal)),
                PdlBadge(
                  label: 'Annonce',
                  tone: tone(c.accentOrange, c.softOrange),
                ),
                PdlBadge(label: 'Publié', tone: tone(c.success, c.softGreen)),
                PdlBadge(label: 'Brouillon', tone: tone(c.neutral, c.softGray)),
                PdlBadge(label: 'Annulé', tone: tone(c.danger, c.softRed)),
                PdlBadge(label: 'Terminée', tone: tone(c.neutral, c.softDone)),
                PdlBadge(
                  label: 'Inscrit',
                  icon: PdlIcons.check,
                  tone: tone(c.primary, c.softIndigo),
                ),
                PdlBadge(
                  label: 'Public',
                  icon: PdlIcons.visibilityPublic,
                  tone: tone(c.accentBlue, c.softBlue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _Caption('taille lg · aplat (catégories de col)'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                PdlBadge(
                  label: 'Organisateur',
                  size: PdlBadgeSize.lg,
                  tone: tone(c.accentBlue, c.softBlue),
                ),
                PdlBadge(
                  label: 'HC',
                  filled: true,
                  tone: tone(c.accentGrape, c.softGrape),
                ),
                PdlBadge(
                  label: 'Cat. 1',
                  filled: true,
                  tone: tone(c.danger, c.softRed),
                ),
                PdlBadge(
                  label: 'Cat. 3',
                  filled: true,
                  tone: PdlTone(
                    fill: c.warning,
                    soft: c.warningSoft,
                    onSoft: c.warningOnSoft,
                    onFill: c.neutralOnSoft,
                    filledStyle: true,
                  ),
                ),
                PdlBadge(
                  label: 'Cat. 4',
                  filled: true,
                  tone: tone(c.success, c.softGreen),
                ),
              ],
            ),
          ],
        ),

        // ── A3 ────────────────────────────────────────────────────────────
        _Block(
          title: 'A3 · PdlButton',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                PdlButton(label: 'Rejoindre', onPressed: () {}),
                PdlButton(
                  label: 'Quitter',
                  variant: PdlButtonVariant.outline,
                  onPressed: () {},
                ),
                PdlButton(
                  label: 'Supprimer le compte',
                  variant: PdlButtonVariant.danger,
                  onPressed: () {},
                ),
                PdlButton(
                  label: 'Voir tout',
                  variant: PdlButtonVariant.text,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _Caption('size sm · icône · pilule · désactivé · en cours'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                PdlButton(
                  label: 'Rejoindre',
                  size: PdlButtonSize.sm,
                  onPressed: () {},
                ),
                PdlButton(
                  label: 'GPX',
                  icon: PdlIcons.gpx,
                  size: PdlButtonSize.sm,
                  variant: PdlButtonVariant.outline,
                  onPressed: () {},
                ),
                PdlButton(
                  label: 'Filtrer',
                  icon: PdlIcons.filter,
                  pill: true,
                  variant: PdlButtonVariant.outline,
                  onPressed: () {},
                ),
                const PdlButton(label: 'Complet', enabled: false),
                const PdlButton(
                  label: "S'inscrire",
                  loading: true,
                  loadingLabel: 'Inscription...',
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _Caption('fullWidth'),
            PdlButton(
              label: "S'inscrire à cette sortie",
              fullWidth: true,
              onPressed: () {},
            ),
          ],
        ),

        // ── A4 ────────────────────────────────────────────────────────────
        _Block(
          title: 'A4 · PdlAvatar',
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const <Widget>[
                PdlAvatar(name: 'Nantes Peloton', size: 56),
                SizedBox(width: 12),
                PdlAvatar(name: 'Gabriel Landais', size: 40),
                SizedBox(width: 12),
                PdlAvatar(name: 'Roger Rabbit', size: 32),
                SizedBox(width: 12),
                PdlAvatar(name: 'Claire Vasseur', size: 26),
                SizedBox(width: 12),
                PdlAvatar(name: 'Marc', size: 20),
                SizedBox(width: 12),
                PdlAvatar(name: 'Ada', size: 16),
              ],
            ),
            const SizedBox(height: 10),
            const _Caption(
              "l'utilisateur courant est toujours primary · anneau de grappe",
            ),
            Row(
              children: const <Widget>[
                PdlAvatar(
                  name: 'Gabriel Landais',
                  size: 40,
                  isCurrentUser: true,
                ),
                SizedBox(width: 12),
                PdlAvatar(name: 'Hélène Ebrard', size: 26, ring: true),
                PdlAvatar(name: 'Ines Barbot', size: 26, ring: true),
                PdlAvatar(name: 'Yann Meunier', size: 26, ring: true),
              ],
            ),
          ],
        ),

        // ── A5 ────────────────────────────────────────────────────────────
        _Block(
          title: 'A5 · PdlCard',
          children: <Widget>[
            PdlCard(
              onTap: () {},
              child: Text(
                'Carte standard, appuyable (échelle 0.98)',
                style: t.body,
              ),
            ),
            const SizedBox(height: 8),
            PdlCard(
              selected: true,
              child: Text('selected — bordure 2 px primary', style: t.body),
            ),
            const SizedBox(height: 8),
            PdlCard(
              flat: true,
              padding: PdlCardPadding.tight,
              child: Text('flat + padding tight (12)', style: t.body),
            ),
          ],
        ),

        // ── A6 / A7 ───────────────────────────────────────────────────────
        _Block(
          title: 'A6 · PdlStat · A7 · PdlStatRow',
          children: <Widget>[
            PdlStatRow(
              stats: <PdlStat>[
                const PdlStat(icon: PdlIcons.distance, value: '46,3 km'),
                const PdlStat(
                  icon: PdlIcons.elevationUp,
                  value: '187 m',
                  trend: PdlStatTrend.up,
                ),
                const PdlStat(
                  icon: PdlIcons.elevationDown,
                  value: '-188 m',
                  trend: PdlStatTrend.down,
                ),
                const PdlStat(
                  icon: PdlIcons.people,
                  value: '40',
                  label: 'participants',
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _Caption('nowrap · big'),
            PdlStatRow(
              nowrap: true,
              stats: const <PdlStat>[
                PdlStat(icon: PdlIcons.time, value: '19:30'),
                PdlStat(icon: PdlIcons.speed, value: '26 km/h'),
                PdlStat(icon: PdlIcons.distance, value: '66,5 km'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: const <Widget>[
                PdlStat(value: '46,3 km', label: 'Distance', big: true),
                SizedBox(width: 24),
                PdlStat(
                  value: '187 m',
                  label: 'Dénivelé',
                  big: true,
                  trend: PdlStatTrend.up,
                ),
              ],
            ),
          ],
        ),

        // ── A8 / A9 / A10 ─────────────────────────────────────────────────
        _Block(
          title:
              'A8 · PdlProgressBar · A9 · PdlColorTrack · A10 · PdlNumberPill',
          children: <Widget>[
            const PdlProgressBar(value: 0.4),
            const SizedBox(height: 8),
            const PdlProgressBar(value: 0.85),
            const SizedBox(height: 8),
            const PdlProgressBar(value: 1),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                PdlColorTrack(color: multiTrackColor(0)),
                const SizedBox(width: 8),
                PdlColorTrack(color: multiTrackColor(1)),
                const SizedBox(width: 8),
                PdlColorTrack(color: multiTrackColor(2)),
                const SizedBox(width: 16),
                PdlColorTrack(
                  color: multiTrackColor(3),
                  shape: PdlColorTrackShape.legend,
                ),
                const SizedBox(width: 8),
                PdlColorTrack(
                  color: multiTrackColor(4),
                  shape: PdlColorTrackShape.legend,
                ),
                const SizedBox(width: 16),
                const PdlNumberPill(value: 1),
                const SizedBox(width: 8),
                const PdlNumberPill(value: 12),
              ],
            ),
          ],
        ),

        // ── A11 ───────────────────────────────────────────────────────────
        _Block(
          title: 'A11 · PdlChip',
          children: <Widget>[
            Wrap(
              spacing: PdlSpacing.chipGap,
              children: <Widget>[
                PdlChip(
                  label: 'Toutes les équipes',
                  icon: PdlIcons.filter,
                  sortStyle: true,
                  onTap: () {},
                ),
                PdlChip(
                  label: 'Tout',
                  selected: _chipSelected,
                  onTap: () => setState(() => _chipSelected = !_chipSelected),
                ),
                PdlChip(label: 'Sorties', onTap: () {}),
                PdlChip(label: 'Gravel', selected: true, onRemoved: () {}),
                PdlChip(label: '40 – 80 km', selected: true, onRemoved: () {}),
              ],
            ),
          ],
        ),

        // ── A12 / A20 ─────────────────────────────────────────────────────
        _Block(
          title: 'A12 · PdlSearchField · A20 · PdlFilterButton',
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: PdlSearchField(
                    value: _search,
                    hintText: 'Rechercher un parcours…',
                    clearTooltip: 'Effacer',
                    onChanged: (String? v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 10),
                PdlFilterButton(
                  onPressed: () {},
                  semanticLabel: 'Filtres',
                  activeCount: 3,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _Caption('erreur · lecture seule'),
            PdlSearchField(
              value: 'abc',
              hintText: 'Rechercher',
              errorText: 'Au moins trois caractères',
              onChanged: (_) {},
            ),
            const SizedBox(height: 8),
            PdlSearchField(
              value: null,
              readOnly: true,
              hintText: 'Choisir une date…',
              onChanged: (_) {},
              onTap: () {},
            ),
          ],
        ),

        // ── A13 ───────────────────────────────────────────────────────────
        _Block(
          title: 'A13 · PdlSectionHeader',
          children: <Widget>[
            PdlSectionHeader(
              title: 'Participants',
              count: '40',
              action: PdlButton(
                label: 'Voir tout',
                variant: PdlButtonVariant.text,
                onPressed: () {},
              ),
            ),
            const PdlSectionHeader(title: 'Prochaines sorties'),
          ],
        ),

        // ── A14 / A15 ─────────────────────────────────────────────────────
        _Block(
          title: 'A14 · PdlSegmented · A15 · PdlSwitch',
          children: <Widget>[
            PdlSegmented<String>(
              segments: const <PdlSegment<String>>[
                PdlSegment<String>(value: 'mois', label: 'Mois'),
                PdlSegment<String>(value: 'agenda', label: 'Agenda'),
              ],
              value: _segment,
              onChanged: (String v) => setState(() => _segment = v),
            ),
            const SizedBox(height: 10),
            PdlSegmented<String>(
              segments: const <PdlSegment<String>>[
                PdlSegment<String>(
                  value: 'clair',
                  label: 'Clair',
                  icon: PdlIcons.theme,
                ),
                PdlSegment<String>(value: 'sombre', label: 'Sombre'),
                PdlSegment<String>(value: 'auto', label: 'Système'),
              ],
              value: 'auto',
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                PdlSwitch(
                  value: _switchOn,
                  semanticLabel: 'Actif',
                  onChanged: (bool v) => setState(() => _switchOn = v),
                ),
                const SizedBox(width: 16),
                PdlSwitch(
                  value: _switchOff,
                  semanticLabel: 'Inactif',
                  onChanged: (bool v) => setState(() => _switchOff = v),
                ),
                const SizedBox(width: 16),
                const PdlSwitch(
                  value: false,
                  onChanged: null,
                  semanticLabel: 'Désactivé',
                ),
              ],
            ),
          ],
        ),

        // ── A16 / A17 ─────────────────────────────────────────────────────
        _Block(
          title: 'A16 · PdlInfoLine · A17 · PdlSettingRow',
          padded: false,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PdlSpacing.section,
              ),
              child: Column(
                children: <Widget>[
                  const PdlInfoLine(label: 'Distance', value: '66,5 km'),
                  const PdlInfoLine(label: 'Revêtement', value: 'Gravel'),
                  PdlInfoLine(
                    label: 'Visibilité',
                    showDivider: false,
                    valueWidget: PdlBadge(
                      label: 'Public',
                      icon: PdlIcons.visibilityPublic,
                      tone: tone(c.accentBlue, c.softBlue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PdlSettingRow(
              icon: PdlIcons.language,
              title: 'Langue',
              trailing: Text('Français', style: t.sub),
              showDivider: true,
              onTap: () {},
            ),
            PdlSettingRow(
              icon: PdlIcons.people,
              title: 'Contact par les membres',
              subtitle: 'Les membres de vos équipes peuvent vous écrire',
              showDivider: true,
              trailing: PdlSwitch(
                value: _switchOn,
                semanticLabel: 'Contact par les membres',
                onChanged: (bool v) => setState(() => _switchOn = v),
              ),
            ),
            PdlSettingRow(
              icon: PdlIcons.logout,
              title: 'Se déconnecter',
              destructive: true,
              onTap: () {},
            ),
          ],
        ),

        // ── A18 / A19 ─────────────────────────────────────────────────────
        _Block(
          title: 'A18 · PdlScrim · A19 · PdlBlurSurface',
          children: <Widget>[
            ClipRRect(
              borderRadius: PdlRadii.cardAll,
              child: SizedBox(
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(gradient: PdlGradients.ride),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: PdlScrim.top(),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: PdlScrim.bottom(),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: PdlBlurSurface(
                        color: c.overlaySolid,
                        sigma: PdlMotion.blurOverlayButton,
                        borderRadius: PdlRadii.mdAll,
                        border: Border.all(color: c.borderSubtle),
                        child: SizedBox(
                          width: PdlMetrics.tapTarget,
                          height: PdlMetrics.tapTarget,
                          child: Icon(PdlIcons.layers, color: c.text),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Text(
                        'Texte sur voile — jamais sans',
                        style: t.cardTitle.copyWith(color: c.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── PdlElevationProfile ───────────────────────────────────────────
        _Block(
          title: 'PdlElevationProfile',
          children: <Widget>[
            const _Caption('110 — écrans 12 et 24 · réticule persistant'),
            PdlElevationProfile(
              samples: _demoProfile,
              height: PdlMetrics.elevationMedium,
              axisLabel: _demoAxisLabel,
              tipLabel: _demoTipLabel,
            ),
            const SizedBox(height: 16),
            const _Caption('72 — compact'),
            PdlElevationProfile(
              samples: _demoProfile,
              height: PdlMetrics.elevationCompact,
              axisLabel: _demoAxisLabel,
              tipLabel: _demoTipLabel,
            ),
            const SizedBox(height: 16),
            const _Caption('chargement'),
            const PdlElevationProfile.loading(
              label: 'Chargement du profil altimétrique...',
              height: PdlMetrics.elevationCompact,
            ),
            const SizedBox(height: 16),
            const _Caption('échec du seul profil'),
            PdlElevationProfile.failed(
              label: 'Profil indisponible',
              actionLabel: 'Réessayer',
              onRetry: () {},
            ),
          ],
        ),

        // ══ Vague B — les 26 composés ═════════════════════════════════════

        // ── B1 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B1 · PdlChipRow',
          padded: false,
          children: <Widget>[
            const _PaddedCaption('hauteur mesurée · fondu des 28 derniers px'),
            PdlChipRow(
              children: <Widget>[
                PdlChip(label: 'Tout', selected: true, onTap: () {}),
                PdlChip(label: 'Sorties', onTap: () {}),
                PdlChip(label: 'Publications', onTap: () {}),
                PdlChip(label: 'Voyages', onTap: () {}),
                PdlChip(label: 'Annonces', onTap: () {}),
                PdlChip(label: 'Parcours', onTap: () {}),
              ],
            ),
          ],
        ),

        // ── B2 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B2 · PdlAvatarStack',
          children: <Widget>[
            PdlAvatarStack(
              people: _demoPeople,
              semanticLabel: '40 participants',
              onTap: () {},
            ),
            const SizedBox(height: 12),
            const _Caption('sans reste, taille 32'),
            PdlAvatarStack(people: _demoPeople.take(3).toList(), size: 32),
          ],
        ),

        // ── B3 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B3 · PdlTeamLine',
          children: <Widget>[
            PdlTeamLine(label: 'N-Peloton', onTap: () {}),
            const SizedBox(height: 8),
            const _Caption('variante voyage — icône au lieu de l\'avatar'),
            PdlTeamLine(
              label: 'Vosges 2026',
              icon: PdlIcons.trip,
              onTap: () {},
            ),
          ],
        ),

        // ── B4 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B4 · PdlPlaceRow',
          children: const <Widget>[
            PdlPlaceRow(
              kind: PdlPlaceKind.start,
              name: 'Fonderies',
              address: '2 boulevard de Berlin, Nantes',
            ),
            SizedBox(height: 12),
            PdlPlaceRow(
              kind: PdlPlaceKind.end,
              name: 'Place du Bourg',
              address: 'Vertou',
            ),
          ],
        ),

        // ── B5 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B5 · PdlThumb',
          children: <Widget>[
            Row(
              children: <Widget>[
                PdlThumb(size: PdlMetrics.thumbLg, onTap: () {}),
                const SizedBox(width: 12),
                const PdlThumb(size: PdlMetrics.thumbMd),
                const SizedBox(width: 12),
                const PdlThumb(
                  size: PdlMetrics.thumbSm,
                  fallbackIcon: PdlIcons.image,
                ),
              ],
            ),
          ],
        ),

        // ── B6 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B6 · PdlCardMedia',
          children: <Widget>[
            const _Caption('208 — dégradé de repli et icône de type'),
            PdlCard(
              padding: PdlCardPadding.none,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const PdlCardMedia(
                    tone: PdlMediaTone.ride,
                    height: PdlMetrics.media16x9,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(PdlSpacing.card),
                    child: Text('N-Peloton #664', style: t.cardTitle),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _Caption('120 · 160 — publication et voyage'),
            Row(
              children: const <Widget>[
                Expanded(
                  child: PdlCardMedia(
                    tone: PdlMediaTone.post,
                    height: PdlMetrics.media120,
                    borderRadius: PdlRadii.cardAll,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: PdlCardMedia(
                    tone: PdlMediaTone.trip,
                    height: PdlMetrics.media120,
                    borderRadius: PdlRadii.cardAll,
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── B7 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B7 · PdlEmptyState — les 4 variantes',
          children: <Widget>[
            PdlCard(
              padding: PdlCardPadding.none,
              child: PdlEmptyState(
                variant: PdlEmptyVariant.empty,
                title: 'Aucune publication',
                message: 'Cette équipe n\'a rien publié pour le moment.',
                actions: <Widget>[
                  PdlButton(
                    label: 'Écrire une publication',
                    size: PdlButtonSize.sm,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            PdlCard(
              padding: PdlCardPadding.none,
              child: PdlEmptyState(
                variant: PdlEmptyVariant.filtered,
                title: 'Aucun résultat',
                message: 'Aucune publication ne correspond à « gravel ».',
                actions: <Widget>[
                  PdlButton(
                    label: 'Effacer la recherche',
                    variant: PdlButtonVariant.outline,
                    size: PdlButtonSize.sm,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            PdlCard(
              padding: PdlCardPadding.none,
              child: PdlEmptyState(
                variant: PdlEmptyVariant.error,
                title: 'Chargement impossible',
                message: 'Vérifiez votre connexion, puis réessayez.',
                actions: <Widget>[
                  PdlButton(
                    label: 'Réessayer',
                    variant: PdlButtonVariant.outline,
                    size: PdlButtonSize.sm,
                    icon: PdlIcons.refresh,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const PdlCard(
              padding: PdlCardPadding.none,
              child: PdlEmptyState(
                variant: PdlEmptyVariant.notFound,
                title: 'Sortie introuvable',
                message: 'Elle a peut-être été supprimée ou rendue privée.',
              ),
            ),
          ],
        ),

        // ── B8 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B8 · PdlBanner',
          children: <Widget>[
            const PdlBanner(
              tone: PdlBannerTone.danger,
              title: 'Inscription impossible.',
              message: 'Vous êtes déjà inscrit dans un autre groupe de cette sortie.',
            ),
            const SizedBox(height: 8),
            PdlBanner(
              tone: PdlBannerTone.warn,
              message: 'Rejoignez cette équipe pour participer aux sorties.',
              action: PdlButton(
                label: 'Voir l\'équipe',
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: () {},
              ),
            ),
            const SizedBox(height: 8),
            const PdlBanner(
              tone: PdlBannerTone.info,
              title: 'Mode hors ligne.',
              message: 'Les données affichées datent de votre dernière visite.',
            ),
          ],
        ),

        // ── B9 ────────────────────────────────────────────────────────────
        _Block(
          title: 'B9 · PdlPagedListFooter',
          children: const <Widget>[
            _Caption('chargement — le total est indispensable'),
            PdlPagedListFooter(
              isLoadingNext: true,
              hasMore: true,
              isEmpty: false,
              progressLabel: '8 participants sur 40',
              loadingLabel: 'chargement de la suite...',
              endLabel: 'Vous avez tout vu',
              errorLabel: 'Impossible de charger la suite.',
              retryLabel: 'Réessayer',
            ),
            _Caption('fin de liste'),
            PdlPagedListFooter(
              isLoadingNext: false,
              hasMore: false,
              isEmpty: false,
              progressLabel: '40 participants sur 40',
              loadingLabel: 'chargement de la suite...',
              endLabel: 'Vous avez tout vu',
              errorLabel: 'Impossible de charger la suite.',
              retryLabel: 'Réessayer',
            ),
            _Caption('échec de la page suivante'),
            PdlPagedListFooter(
              isLoadingNext: false,
              hasMore: true,
              isEmpty: false,
              hasError: true,
              progressLabel: '8 participants sur 40',
              loadingLabel: 'chargement de la suite...',
              endLabel: 'Vous avez tout vu',
              errorLabel:
                  'Impossible de charger la suite.\n'
                  'Vérifiez votre connexion.',
              retryLabel: 'Réessayer',
            ),
          ],
        ),

        // ── B10 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B10 · PdlPersonRow',
          children: <Widget>[
            PdlPersonRow(
              name: 'Antoine Yvon',
              organizerFlag: true,
              organizerLabel: 'Organisateur du groupe',
              showDivider: true,
              onTap: () {},
            ),
            PdlPersonRow(
              name: 'Hélène Ebrard',
              subtitle: 'N-Peloton · inscrite depuis 2024',
              showDivider: true,
              roleBadge: PdlBadge(
                label: 'Admin',
                tone: tone(c.primary, c.softIndigo),
              ),
              onTap: () {},
            ),
            const PdlPersonRow(
              name: 'Gabriel Landais',
              isCurrentUser: true,
              subtitle: 'C\'est vous',
            ),
          ],
        ),

        // ── B11 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B11 · PdlAttachmentRow',
          children: <Widget>[
            PdlAttachmentRow(
              name: 'np664-chill-gravel.gpx',
              type: 'gpx',
              subtitle: '412 ko',
              actionSemanticLabel: 'Télécharger np664-chill-gravel.gpx',
              onAction: () {},
              showDivider: true,
            ),
            PdlAttachmentRow(
              name: 'Roadbook Vosges 2026.pdf',
              type: 'pdf',
              icon: PdlIcons.page,
              actionSemanticLabel: 'Télécharger Roadbook Vosges 2026.pdf',
              onAction: () {},
            ),
          ],
        ),

        // ── B12 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B12 · PdlLegendRow',
          padded: false,
          children: <Widget>[
            const _PaddedCaption('l\'entrée active passe en text/600'),
            PdlLegendRow(
              activeIndex: 1,
              entries: <PdlLegendEntry>[
                PdlLegendEntry(
                  color: multiTrackColor(0),
                  label: 'Chill Route Court',
                  onTap: () {},
                ),
                PdlLegendEntry(
                  color: multiTrackColor(1),
                  label: 'Chill Route Long',
                  onTap: () {},
                ),
                PdlLegendEntry(
                  color: multiTrackColor(2),
                  label: 'G1',
                  onTap: () {},
                ),
                PdlLegendEntry(
                  color: multiTrackColor(3),
                  label: 'G2',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),

        // ── B13 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B13 · PdlClimbRow',
          children: <Widget>[
            PdlClimbRow(
              categoryLabel: 'HC',
              categoryTone: PdlTone(
                fill: c.accentGrape,
                soft: c.grapeSoft,
                onSoft: c.grapeOnSoft,
                filledStyle: true,
              ),
              name: 'Col de la Schlucht',
              range: '12,4 → 18,1 km',
              figures: const <PdlClimbFigure>[
                PdlClimbFigure(value: '5,7 km', label: 'long.'),
                PdlClimbFigure(value: '412 m', label: 'D+'),
                PdlClimbFigure(value: '7,2 %', label: 'moy.'),
              ],
            ),
            PdlClimbRow(
              categoryLabel: 'Cat. 3',
              categoryTone: PdlTone(
                fill: c.warning,
                soft: c.warningSoft,
                onSoft: c.warningOnSoft,
                onFill: c.neutralOnSoft,
                filledStyle: true,
              ),
              name: 'Côte de Vertou',
              range: '31,0 → 32,6 km',
              showDivider: false,
              figures: const <PdlClimbFigure>[
                PdlClimbFigure(value: '1,6 km', label: 'long.'),
                PdlClimbFigure(value: '74 m', label: 'D+'),
                PdlClimbFigure(value: '4,6 %', label: 'moy.'),
              ],
            ),
          ],
        ),

        // ── Points de parcours (MOB-84) ──────────────────────────────────
        _Block(
          title: 'PdlWaypointRow · PdlWaypointBadge',
          children: <Widget>[
            PdlWaypointRow(
              mark: _demoMark(PdlIcons.waypointSupply, c.accentOrange),
              distanceLabel: '12,3 km',
              title: 'Café du Port',
              subtitle: 'Ravitaillement',
              description: 'Ouvert dès 8 h, terrasse au soleil.',
              selected: true,
              onTap: () {},
            ),
            PdlWaypointRow(
              mark: _demoMark(PdlIcons.waypointDanger, c.danger),
              distanceLabel: 'Hors tracé',
              title: 'Danger',
              onTap: () {},
              showDivider: false,
            ),
            const SizedBox(height: 12),
            PdlElevationProfile(
              samples: _demoProfile,
              height: PdlMetrics.elevationMedium,
              axisLabel: _demoAxisLabel,
              tipLabel: _demoTipLabel,
              selectedMarkerKey: 'b',
              onMarkerTapped: (String _) {},
              markers: <PdlProfileMarker>[
                PdlProfileMarker(
                  key: 'a',
                  distance: _demoProfile.totalDistance * 0.2,
                  mark: _demoMark(PdlIcons.waypointWater, c.accentBlue),
                  priority: 5,
                ),
                PdlProfileMarker(
                  key: 'b',
                  distance: _demoProfile.totalDistance * 0.5,
                  mark: _demoMark(PdlIcons.waypointSummit, c.accentGrape),
                  priority: 7,
                ),
                PdlProfileMarker(
                  key: 'c',
                  distance: _demoProfile.totalDistance * 0.8,
                  mark: _demoMark(PdlIcons.waypointDanger, c.danger),
                  priority: 11,
                ),
              ],
            ),
          ],
        ),

        // ── B14 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B14 · PdlStatCellRow',
          children: <Widget>[
            PdlStatCellRow(
              cells: <PdlStatCell>[
                PdlStatCell(
                  value: '12',
                  label: 'À venir',
                  onTap: () {},
                  semanticLabel: '12 sorties à venir',
                ),
                const PdlStatCell(value: '184', label: 'Historique'),
                const PdlStatCell(value: '4 210 km', label: 'Cette année'),
              ],
            ),
          ],
        ),

        // ── B15 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B15 · PdlAvatarEditor',
          children: <Widget>[
            Center(
              child: PdlAvatarEditor(
                name: 'Gabriel Landais',
                onPick: () {},
                pickSemanticLabel: 'Changer la photo de profil',
                onRemove: () {},
                removeLabel: 'Supprimer la photo',
              ),
            ),
          ],
        ),

        // ── B16 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B16 · PdlDangerZone',
          padded: false,
          children: <Widget>[
            PdlDangerZone(
              title: 'Supprimer mon compte',
              consequence:
                  'Cette action est irréversible : vos inscriptions, vos '
                  'publications et vos parcours seront supprimés.',
              actionLabel: 'Supprimer mon compte',
              onAction: () {},
            ),
          ],
        ),

        // ── B17 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B17 · PdlRangeFilter',
          children: <Widget>[
            PdlRangeFilter(
              values: _range,
              min: 0,
              max: 200,
              divisions: 40,
              lowLabel: '0 km',
              highLabel: '200 km',
              semanticFormatter: (double v) => '${v.round()} km',
              onChanged: (RangeValues v) => setState(() => _range = v),
            ),
          ],
        ),

        // ── B18 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B18 · PdlGalleryDots',
          children: <Widget>[
            ClipRRect(
              borderRadius: PdlRadii.cardAll,
              child: SizedBox(
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const DecoratedBox(
                      decoration: BoxDecoration(gradient: PdlGradients.ad),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: PdlGalleryDots(
                          count: 4,
                          index: _dotIndex,
                          semanticLabel: 'Photo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            PdlButton(
              label: 'Photo suivante',
              variant: PdlButtonVariant.outline,
              size: PdlButtonSize.sm,
              onPressed: () => setState(() => _dotIndex = (_dotIndex + 1) % 4),
            ),
          ],
        ),

        // ── B19 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B19 · PdlPriceBlock',
          children: <Widget>[
            const PdlPriceBlock(price: '1 250 €', note: 'Prix à débattre'),
            const SizedBox(height: 8),
            PdlPriceBlock(
              price: '35 € / jour',
              note: 'Location, caution 300 €',
              trailing: PdlButton(
                label: 'Contacter',
                size: PdlButtonSize.sm,
                onPressed: () {},
              ),
            ),
          ],
        ),

        // ── B20 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B20 · PdlBadgeStack',
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: PdlBadgeStack(
                badges: <Widget>[
                  PdlBadge(
                    label: 'Sortie',
                    tone: tone(c.accentBlue, c.softBlue),
                  ),
                  PdlBadge(label: 'Publié', tone: tone(c.success, c.softGreen)),
                  PdlBadge(
                    label: 'Public',
                    icon: PdlIcons.visibilityPublic,
                    tone: tone(c.accentBlue, c.softBlue),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Tags d'équipe (MOB-39) ────────────────────────────────────────
        _Block(
          title: 'PdlTag · PdlTagRow — pastille, pas badge',
          children: <Widget>[
            const _Caption('carte : 3 puis « +n »'),
            PdlTagRow(
              maxVisible: 3,
              tags: <PdlTagEntry>[
                PdlTagEntry(label: 'Café', color: c.success),
                PdlTagEntry(label: 'Gravel', color: c.accentOrange),
                PdlTagEntry(label: 'Montagne', color: c.accentGrape),
                PdlTagEntry(label: 'Nocturne', color: c.primary),
              ],
            ),
            const SizedBox(height: 8),
            const _Caption('fiche : tous'),
            PdlTagRow(
              tags: <PdlTagEntry>[
                PdlTagEntry(label: 'Café', color: c.success),
                PdlTagEntry(label: 'Gravel', color: c.accentOrange),
                PdlTagEntry(label: 'Montagne', color: c.accentGrape),
                PdlTagEntry(label: 'Nocturne', color: c.primary),
              ],
            ),
          ],
        ),

        // ── Météo : flèche de vent, barre de segments ─────────────────────
        _Block(
          title: 'PdlWindArrow · PdlSegmentBar — le vent',
          children: <Widget>[
            const _Caption('flèche : 0 dos · 90 travers · 180 face · 225'),
            Row(
              children: <Widget>[
                PdlWindArrow(angle: 0, color: c.accentTeal),
                const SizedBox(width: 16),
                PdlWindArrow(angle: 90, color: c.neutral),
                const SizedBox(width: 16),
                PdlWindArrow(angle: 180, color: c.accentOrange),
                const SizedBox(width: 16),
                const PdlWindArrow(angle: 225, size: 28),
              ],
            ),
            const SizedBox(height: 12),
            const _Caption('vent le long du parcours'),
            PdlSegmentBar(
              semanticLabel: 'Face 12 km, travers 30 km, dos 24 km',
              entries: <PdlSegmentBarEntry>[
                PdlSegmentBarEntry(extent: 15000, color: c.accentTeal),
                PdlSegmentBarEntry(extent: 15000, color: c.neutral),
                PdlSegmentBarEntry(extent: 12000, color: c.accentOrange),
                PdlSegmentBarEntry(extent: 15000, color: c.neutral),
                PdlSegmentBarEntry(extent: 9000, color: c.accentTeal),
              ],
            ),
            const SizedBox(height: 8),
            const _Caption('vide'),
            const PdlSegmentBar(entries: <PdlSegmentBarEntry>[]),
          ],
        ),

        // ── B21 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B21 · PdlSkeletonCard — 5 squelettes, pas 2',
          children: const <Widget>[
            _Caption('gabarit média 208'),
            PdlSkeletonCard(),
            SizedBox(height: 8),
            _Caption('ligne compacte 100'),
            PdlSkeletonCard(variant: PdlSkeletonCardVariant.compact),
            SizedBox(height: 8),
            _Caption('personne 56'),
            PdlSkeletonCardList(
              variant: PdlSkeletonCardVariant.person,
              count: 3,
            ),
          ],
        ),

        // ── B22 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B22 · PdlDeadEndEmpty',
          padded: false,
          children: <Widget>[
            PdlDeadEndEmpty(
              title: 'Aucun parcours',
              message:
                  'Aucun parcours ne contient « gravel » avec les filtres '
                  'Distance 40–80 km et Revêtement Route.',
              removeFilterLabel: 'Retirer le filtre Revêtement',
              onRemoveFilter: () {},
              resetAllLabel: 'Tout réinitialiser',
              onResetAll: () {},
              previewTitle: 'Sans le filtre Revêtement',
              preview: <Widget>[
                for (final String name in const <String>[
                  'NP664 - CHILL GRAVEL',
                  'NP663 - ROUTE LONGUE',
                  'NP661 - BORDS DE LOIRE',
                ])
                  PdlCard(
                    padding: PdlCardPadding.tight,
                    onTap: () {},
                    child: Row(
                      children: <Widget>[
                        Icon(PdlIcons.route, size: 20, color: c.textDimmed),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(name, style: t.bodyStrong),
                              Text('46,3 km · 187 m', style: t.xs),
                            ],
                          ),
                        ),
                        Icon(
                          PdlIcons.chevronRight,
                          size: 20,
                          color: c.textPlaceholder,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),

        // ── B23 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B23 · PdlScopeSelector',
          children: <Widget>[
            PdlScopeSelector(
              label: 'Toutes mes équipes',
              onTap: () {},
              semanticLabel: 'Portée : toutes mes équipes',
            ),
            const SizedBox(height: 12),
            const _Caption('variante ligne — barre d\'outils du calendrier'),
            PdlScopeSelector(
              label: 'N-Peloton',
              style: PdlScopeStyle.row,
              onTap: () {},
            ),
          ],
        ),

        // ── B24 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B24 · PdlMarkdownBody',
          children: <Widget>[
            // Branché sur le vrai routeur de liens : une galerie dont les
            // liens ne font rien ne montrerait pas le composant, elle
            // montrerait le défaut qu'on vient de corriger (F-DE-6).
            PdlMarkdownBody(
              data: _demoMarkdown,
              onLinkTap: (String href) => unawaited(openLink(context, href)),
            ),
          ],
        ),

        // ── B25 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B25 · PdlImageViewer',
          children: <Widget>[
            const _Caption('pincement · balayage vertical pour fermer'),
            PdlButton(
              label: 'Ouvrir la visionneuse',
              variant: PdlButtonVariant.outline,
              icon: PdlIcons.image,
              onPressed: () => PdlImageViewer.show(
                context,
                imageProvider: const AssetImage('assets/icon.png'),
                closeSemanticLabel: 'Fermer',
                caption: Text(
                  'Départ des Fonderies',
                  style: t.sub.copyWith(color: c.onPrimary),
                ),
              ),
            ),
          ],
        ),

        // ── B26 ───────────────────────────────────────────────────────────
        _Block(
          title: 'B26 · PdlMonthGrid + PdlDayHeader',
          children: <Widget>[
            const _Caption(
              'semaine lundi → dimanche calculée · aujourd\'hui et inscrit '
              'cumulables',
            ),
            PdlMonthGrid(
              year: 2026,
              month: 7,
              weekdayLabels: const <String>[
                'lun.',
                'mar.',
                'mer.',
                'jeu.',
                'ven.',
                'sam.',
                'dim.',
              ],
              today: _demoToday,
              selectedDay: _selectedDay,
              isRegistered: (DateTime d) =>
                  d.day == 22 || d.day == 19 || d.day == 26,
              dotsOf: (DateTime d) => <Color>[
                if (d.day % 7 == 1) c.accentBlue,
                if (d.day % 5 == 2) c.accentTeal,
              ],
              onDayTap: (DateTime d) => setState(() => _selectedDay = d),
            ),
            const PdlDayHeader(label: 'mer. 22 juillet'),
            PdlCard(
              padding: PdlCardPadding.tight,
              onTap: () {},
              child: Text('N-Peloton #664', style: t.bodyStrong),
            ),
          ],
        ),

        // ── C1 ────────────────────────────────────────────────────────────
        _Block(
          title: 'C1 · PdlAppBar',
          padded: false,
          children: <Widget>[
            const _PaddedCaption('solid · titre + retour + action'),
            PdlAppBar(
              title: 'Détail de la sortie',
              onBack: () {},
              backSemanticLabel: 'Retour',
              actions: <Widget>[
                PdlAppBarAction(
                  icon: PdlIcons.share,
                  semanticLabel: 'Partager',
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: PdlSpacing.sectionTightV),
            const _PaddedCaption('solid · logotype de l\'accueil'),
            PdlAppBar(
              titleWidget: Text('Pédalons', style: t.wordmark),
              actions: <Widget>[
                PdlAppBarAction(
                  icon: PdlIcons.search,
                  semanticLabel: 'Rechercher',
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: PdlSpacing.sectionTightV),
            const _PaddedCaption('overlay · posée sur une tuile'),
            SizedBox(
              height: PdlMetrics.media,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: PdlGradients.ride,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PdlScrim.top(),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PdlAppBar(
                      variant: PdlAppBarVariant.overlay,
                      title: 'Boucle de la Loire',
                      onBack: () {},
                      backSemanticLabel: 'Retour',
                      actions: <Widget>[
                        PdlAppBarAction(
                          icon: PdlIcons.share,
                          semanticLabel: 'Partager',
                          variant: PdlAppBarVariant.overlay,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── C2 ────────────────────────────────────────────────────────────
        _Block(
          title: 'C2 · PdlBottomTabs',
          padded: false,
          children: <Widget>[
            const _PaddedCaption(
              'cinq entrées racine · aucune variante équipe',
            ),
            PdlBottomTabs(
              items: kDemoTabs,
              selectedIndex: _tab,
              onSelected: (int i) => setState(() => _tab = i),
            ),
          ],
        ),

        // ── C3, C4, C8 ────────────────────────────────────────────────────
        _Block(
          title:
              'C3 · PdlPinnedToolbar · C4 · PdlActionBar · C8 · '
              'PdlScreenScaffold',
          children: <Widget>[
            const _Caption(
              'l\'empilement complet vit dans son propre écran : barre '
              'épinglée au défilement, feuille par-dessus les onglets',
            ),
            PdlButton(
              label: 'Ouvrir la coquille de démonstration',
              variant: PdlButtonVariant.outline,
              fullWidth: true,
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => PdlShellDemoPage(
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),

        // ── C5, C6 ────────────────────────────────────────────────────────
        _Block(
          title: 'C5 · PdlSheet · C6 · PdlFullSheet',
          children: <Widget>[
            const _Caption(
              'en-tête fixe · corps défilant borné · pied fixe ; navigateur '
              'racine, donc au-dessus des onglets',
            ),
            PdlButton(
              label: 'Feuille simple',
              variant: PdlButtonVariant.outline,
              fullWidth: true,
              onPressed: () => PdlSheet.show<void>(
                context: context,
                builder: (BuildContext sheetContext) => PdlSheet(
                  title: 'Trier par',
                  footer: Padding(
                    padding: const EdgeInsets.all(PdlSpacing.section),
                    child: PdlButton(
                      label: 'Appliquer',
                      fullWidth: true,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                  children: <Widget>[
                    for (final String option in <String>[
                      'Date',
                      'Distance',
                      'Dénivelé',
                    ])
                      PdlSettingRow(
                        title: option,
                        onTap: () => Navigator.of(sheetContext).pop(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: PdlSpacing.chipGap),
            PdlButton(
              label: 'Feuille plein rideau',
              variant: PdlButtonVariant.outline,
              fullWidth: true,
              onPressed: () => PdlFullSheet.show<void>(
                context: context,
                builder: (BuildContext sheetContext) => PdlFullSheet(
                  title: 'Participants',
                  headerAction: PdlAppBarAction(
                    icon: PdlIcons.close,
                    semanticLabel: 'Fermer',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                  bodyBuilder:
                      (BuildContext context, ScrollController controller) =>
                          ListView.builder(
                            controller: controller,
                            itemCount: _demoPeople.length * 4,
                            itemBuilder: (BuildContext context, int i) =>
                                PdlPersonRow(
                                  name:
                                      _demoPeople[i % _demoPeople.length].name,
                                ),
                          ),
                ),
              ),
            ),
          ],
        ),

        // ── C7 ────────────────────────────────────────────────────────────
        _Block(
          title: 'C7 · PdlDetentSheet',
          padded: false,
          children: <Widget>[
            const _PaddedCaption('crans .18 / .5 / .92 · pied fixe'),
            SizedBox(
              height: 320,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: ColoredBox(color: c.surfaceAlt)),
                  PdlDetentSheet(
                    headerBuilder: (BuildContext context, double extent) =>
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PdlSpacing.section,
                            vertical: PdlSpacing.sectionTightV,
                          ),
                          child: Text(
                            extent > 0.35 ? '12 parcours' : '12 parcours ›',
                            style: t.sectionTitle,
                          ),
                        ),
                    bodyBuilder:
                        (
                          BuildContext context,
                          ScrollController controller,
                          double footerInset,
                        ) => ListView.builder(
                          controller: controller,
                          padding: EdgeInsets.only(bottom: footerInset),
                          itemCount: 20,
                          itemBuilder: (BuildContext context, int i) =>
                              PdlSettingRow(
                                title: 'Boucle n° ${i + 1}',
                                onTap: () {},
                              ),
                        ),
                    footer: PdlActionBar(
                      children: <Widget>[
                        PdlButton(label: 'Filtrer', onPressed: () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── C9 ────────────────────────────────────────────────────────────
        _Block(
          title: 'C9 · PdlStageRail',
          padded: false,
          children: <Widget>[
            const _PaddedCaption(
              'pastille active recentrée · troncature par graphèmes',
            ),
            PdlStageRail(
              items: const <PdlStageRailItem>[
                PdlStageRailItem(label: 'Aperçu'),
                PdlStageRailItem(label: 'J1', sublabel: 'Saint-Étienne'),
                PdlStageRailItem(label: 'J2', sublabel: 'Col de la Croix 🚴'),
                PdlStageRailItem(label: 'J3', sublabel: 'Vallée du Rhône'),
                PdlStageRailItem(label: 'J4', sublabel: 'Mont Ventoux'),
                PdlStageRailItem(label: 'J5', sublabel: 'Retour par la Loire'),
              ],
              selectedIndex: _stage,
              onSelected: (int i) => setState(() => _stage = i),
            ),
          ],
        ),

        // ── C10 ───────────────────────────────────────────────────────────
        _Block(
          title: 'C10 · PdlPrevNextNav',
          children: <Widget>[
            const _Caption('deux blocs de 64 · le suivant inversé'),
            PdlPrevNextNav(
              previous: PdlPrevNextTarget(
                caption: 'Publication précédente',
                title: 'Trêve estivale : pas de sortie du 15 au 28 juillet',
                onTap: () {},
              ),
              next: PdlPrevNextTarget(
                caption: 'Publication suivante',
                title: 'Compte rendu de la sortie longue du 12 juillet',
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quelques personnes pour les grappes et les lignes de personne.
const List<PdlAvatarEntry> _demoPeople = <PdlAvatarEntry>[
  PdlAvatarEntry(name: 'Nicolas Bertin'),
  PdlAvatarEntry(name: 'Claire Vasseur'),
  PdlAvatarEntry(name: 'Benoît Lecomte'),
  PdlAvatarEntry(name: 'Julie Daumas'),
  PdlAvatarEntry(name: 'Yann Marchand'),
  PdlAvatarEntry(name: 'Gabriel Landais', isCurrentUser: true),
  PdlAvatarEntry(name: 'Hélène Ebrard'),
  PdlAvatarEntry(name: 'Antoine Yvon'),
];

const String _demoMarkdown = '''
## Départ des Fonderies

Quatre groupes au programme, retour par les **bords de Loire**. Pensez aux
éclairages : le retour se fera de nuit.

- Rendez-vous 19h15, départ 19h30
- Prévoir une chambre à air
- [Le parcours complet](https://example.org/parcours)

> Sortie annulée en cas de pluie forte annoncée à 18h.

| Groupe | Allure | Distance |
| --- | --- | --- |
| Chill Route Court | 22 km/h | 47,0 km |
| Chill Route Long | 26 km/h | 66,5 km |
| G1 | 30 km/h | 72,3 km |

Code d'accès du local : `4C6E-F5`.
''';

/// Appareillage de planche — n'appartient pas à la charte.
class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.children,
    this.padded = true,
  });

  final String title;
  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              12,
            ),
            child: Text(
              title.toUpperCase(),
              style: t.mono.copyWith(color: c.textPlaceholder),
            ),
          ),
          if (padded)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PdlSpacing.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
        ],
      ),
    );
  }
}

/// Légende d'un bloc non rembourré — les rangées défilantes vont bord à bord,
/// leur légende, non.
class _PaddedCaption extends StatelessWidget {
  const _PaddedCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      PdlSpacing.section,
      0,
      PdlSpacing.section,
      6,
    ),
    child: Text(text, style: context.pdlText.mono),
  );
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: context.pdlText.mono),
  );
}

/// Profil de démonstration : 300 points, une bosse et une descente, de quoi
/// balayer toute l'échelle de pente.
///
/// Construit **une fois** et gardé : le painter de l'aire compare son profil
/// par identité, le reconstruire à chaque `build` le ferait repeindre.
final ElevationSamples _demoProfile = ElevationSamples.fromPoints(
  <ElevationPoint>[
    for (int i = 0; i < 300; i++)
      ElevationPoint(
        distance: i * 155.0,
        elevation: 120 + 180 * (1 - (i / 150 - 1).abs()) + (i % 7) * 3,
        grade: i == 0 ? 0 : (i < 150 ? 12 * (i / 150) : -9 * ((i - 150) / 150)),
      ),
  ],
);

/// La galerie n'a ni locale ni préférence d'unités : elle formate à la main.
/// Dans l'app, ces deux fonctions passent par `AppFormatters`.
String _demoAxisLabel(double meters, {required bool isLast}) {
  final String value = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return isLast ? '$value km' : value;
}

String _demoTipLabel(ElevationReading reading) {
  final String km = (reading.distance / 1000)
      .toStringAsFixed(1)
      .replaceAll('.', ',');
  final String grade = reading.grade == null
      ? '—'
      : '${reading.grade!.toStringAsFixed(1).replaceAll('.', ',')} %';
  return '$km km · ${reading.elevation.round()} m · $grade';
}

PdlWaypointMark _demoMark(IconData glyph, Color disc) =>
    PdlWaypointMark(glyph: glyph, disc: disc, onDisc: const Color(0xFFFFFFFF));
