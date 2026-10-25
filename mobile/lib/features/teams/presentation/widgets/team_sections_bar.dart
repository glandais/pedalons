import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import 'team_sections.dart';

/// The row of team sections — Dashboard, Agenda, Publications, Routes, Ads,
/// Members, About.
///
/// **This is content, not navigation.** It used to be a second `NavigationBar`
/// stacked under the app one, which replaced the five global tabs as soon as
/// one entered a team. It is now a [PdlChipRow] sitting under the team header,
/// so a team is a page of the Teams tab like any other.
///
/// Two forms, one look. [TeamSectionsToolbar] is the sliver form — a
/// [PdlPinnedToolbar], so the row stays reachable however far the section
/// scrolls. [TeamSectionsBar] is the box form, for the sections whose body is
/// a page of its own rather than a list of slivers (the agenda's calendar,
/// route library, classifieds): the bar is then fixed above that body, which reads the same
/// since a pinned toolbar placed first in a scroll view never moves either.
class TeamSectionsBar extends StatelessWidget {
  const TeamSectionsBar({
    super.key,
    required this.sections,
    required this.current,
  });

  final List<TeamSection> sections;
  final TeamSectionKind current;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    return PdlBlurSurface(
      color: c.overlaySolid,
      border: Border(bottom: BorderSide(color: c.borderSubtle)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: PdlMetrics.toolbarPadding,
        ),
        child: TeamSectionChips(sections: sections, current: current),
      ),
    );
  }
}

/// The sliver form of [TeamSectionsBar]: pinned under the team header.
class TeamSectionsToolbar extends StatelessWidget {
  const TeamSectionsToolbar({
    super.key,
    required this.sections,
    required this.current,
  });

  final List<TeamSection> sections;
  final TeamSectionKind current;

  @override
  Widget build(BuildContext context) => PdlPinnedToolbar(
    child: TeamSectionChips(sections: sections, current: current),
  );
}

/// The chips themselves, shared by both forms.
///
/// The row is wider than the screen as soon as a team has a few sections, so
/// the selected chip, when it is not whole on screen, is scrolled into view —
/// centred where the row allows it — when the section opens: « Parcours » or « À propos » would otherwise sit
/// past the edge, and nothing on screen would say where one is.
class TeamSectionChips extends StatefulWidget {
  const TeamSectionChips({
    super.key,
    required this.sections,
    required this.current,
  });

  final List<TeamSection> sections;
  final TeamSectionKind current;

  @override
  State<TeamSectionChips> createState() => _TeamSectionChipsState();
}

class _TeamSectionChipsState extends State<TeamSectionChips> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(TeamSectionChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) _revealSelected(animate: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the row only. `Scrollable.ensureVisible` would also move every
  /// enclosing scrollable — the section's own list, under a pinned toolbar.
  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderObject? chip = _selectedKey.currentContext
          ?.findRenderObject();
      // A page covered by an opaque route is offstage: the Overlay skips its
      // layout, so the chip may have no size yet.
      if (!mounted ||
          chip is! RenderBox ||
          !chip.hasSize ||
          !_scroll.hasClients) {
        return;
      }
      final ScrollPosition position = _scroll.position;
      final RenderAbstractViewport viewport = RenderAbstractViewport.of(chip);
      // Already whole on screen: leave the row where it is.
      final double atEnd = viewport.getOffsetToReveal(chip, 1).offset;
      final double atStart = viewport.getOffsetToReveal(chip, 0).offset;
      if (position.pixels >= atEnd && position.pixels <= atStart) return;
      final double target = viewport
          .getOffsetToReveal(chip, 0.5)
          .offset
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        _scroll.animateTo(
          target,
          duration: PdlMotion.stateChange,
          curve: PdlMotion.stateChangeCurve,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<TeamSection> sections = widget.sections;
    final int selected = indexOfSection(widget.current, sections);

    return PdlChipRow(
      controller: _scroll,
      children: <Widget>[
        for (int i = 0; i < sections.length; i++)
          PdlChip(
            key: i == selected ? _selectedKey : null,
            label: sections[i].label.tr(),
            icon: sections[i].icon,
            selected: i == selected,
            // Sections replace one another inside the Teams branch rather than
            // stacking: going back from a section leads out of the team, not
            // through every section visited on the way.
            onTap: i == selected
                ? null
                : () => context.go(sections[i].currentPath),
          ),
      ],
    );
  }
}
