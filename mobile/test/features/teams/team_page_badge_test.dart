import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/teams/domain/team_page_badge.dart';

TeamPageSummaryDto _page({
  String visibility = 'PUBLIC',
  String status = 'PUBLISHED',
  bool moderationHidden = false,
}) => TeamPageSummaryDto(
  id: 'p1',
  title: 'Histoire',
  slug: 'histoire',
  visibility: visibility,
  order: 0,
  deleted: false,
  status: status,
  moderationHidden: moderationHidden,
);

// docs/LEDGER_*.md WEB-120 — même règle que `pageBadge` du site.
void main() {
  test('rien pour une page publiée et publique', () {
    expect(teamPageBadge(_page(), isMember: false), isNull);
    expect(teamPageBadge(_page(), isMember: true), isNull);
  });

  test('brouillon et masquée, masquée d\'abord', () {
    expect(
      teamPageBadge(_page(status: 'DRAFT'), isMember: true),
      TeamPageBadge.draft,
    );
    expect(
      teamPageBadge(_page(moderationHidden: true), isMember: true),
      TeamPageBadge.hidden,
    );
    expect(
      teamPageBadge(
        _page(status: 'DRAFT', moderationHidden: true),
        isMember: true,
      ),
      TeamPageBadge.hidden,
    );
  });

  test('« Membres » seulement pour qui n\'est pas de l\'équipe', () {
    expect(
      teamPageBadge(_page(visibility: 'TEAM'), isMember: false),
      TeamPageBadge.members,
    );
    expect(teamPageBadge(_page(visibility: 'TEAM'), isMember: true), isNull);
  });
}
