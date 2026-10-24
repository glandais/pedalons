import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.generated.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';

import 'team_fixtures.dart';

/// Ledger `MOB-87` — où mène « Mes équipes » dans l'autre équipe : la même
/// section si elle l'a, son tableau de bord sinon. Mêmes cas que
/// `teamSwitchPath` côté site.
void main() {
  setUp(() => setCurrentLocale('fr'));

  final TeamDetailDto member = fixtureTeam(slug: 'pilat', role: 'MEMBER');

  String target(TeamDetailDto team, TeamSectionKind current) =>
      switchTargetSection(team, current).currentPath;

  test('le tableau de bord reste le tableau de bord', () {
    expect(target(member, TeamSectionKind.dashboard), Paths.team('pilat'));
  });

  test('l\'Agenda reste l\'Agenda, nu', () {
    expect(target(member, TeamSectionKind.agenda), Paths.teamAgenda('pilat'));
  });

  test('sans sorties ni voyages, l\'Agenda mène au tableau de bord', () {
    final TeamDetailDto team = member.copyWith(
      enableRides: false,
      enableTrips: false,
    );
    expect(target(team, TeamSectionKind.agenda), Paths.team('pilat'));
  });

  test('sans parcours, ni Agenda ni Parcours', () {
    final TeamDetailDto team = member.copyWith(enableRoutes: false);
    expect(target(team, TeamSectionKind.agenda), Paths.team('pilat'));
    expect(target(team, TeamSectionKind.routes), Paths.team('pilat'));
  });

  test('les publications, si l\'équipe en a', () {
    expect(target(member, TeamSectionKind.posts), Paths.teamPosts('pilat'));
    expect(
      target(member.copyWith(enablePosts: false), TeamSectionKind.posts),
      Paths.team('pilat'),
    );
  });

  test('les parcours', () {
    expect(target(member, TeamSectionKind.routes), Paths.routes('pilat'));
  });

  test('les annonces, aux membres d\'une équipe qui en a', () {
    expect(target(member, TeamSectionKind.ads), Paths.teamAds('pilat'));
    expect(
      target(member.copyWith(enableAds: false), TeamSectionKind.ads),
      Paths.team('pilat'),
    );
    expect(
      target(fixtureTeam(slug: 'pilat'), TeamSectionKind.ads),
      Paths.team('pilat'),
    );
  });

  test('les membres, selon le rôle et le trombinoscope', () {
    expect(target(member, TeamSectionKind.members), Paths.team('pilat'));
    expect(
      target(
        member.copyWith(enableMemberDirectory: true),
        TeamSectionKind.members,
      ),
      Paths.teamMembers('pilat'),
    );
    expect(
      target(
        fixtureTeam(slug: 'pilat', role: 'ORGANIZER'),
        TeamSectionKind.members,
      ),
      Paths.teamMembers('pilat'),
    );
  });

  test('À propos, toujours là', () {
    expect(
      target(fixtureTeam(slug: 'pilat'), TeamSectionKind.about),
      Paths.teamAbout('pilat'),
    );
  });
}
