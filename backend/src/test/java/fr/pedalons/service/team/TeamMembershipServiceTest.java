package fr.pedalons.service.team;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.teams.response.MemberDto;
import fr.pedalons.dto.teams.response.MemberListResponse;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.ad.AdService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamMembershipServiceTest extends AbstractBaseTest {

  @Inject TeamMembershipService membershipService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext queryContext;
  @Inject AdService adService;
  @Inject DomainResolver domainResolver;

  private Domain domain;
  private Team team;
  private User admin;
  private User user1;
  private User user2;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    dataService.setTeamJoinable(team, true);
    dataService.setTeamAddMemberAllowed(team, true);
    user1 = dataService.createUser("user1@example.com", "User One");
    user2 = dataService.createUser("user2@example.com", "User Two");
  }

  // ==================== Get Team Members ====================

  @Test
  void getTeamMembers_shouldReturnMembersForAdmin() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);
    dataService.addUserToTeam(user2, team, TeamRole.ORGANIZER);

    queryContext.setUserForTest(admin);
    MemberListResponse result = membershipService.getTeamMembers(team.getSlug(), 0, 10, null, null);

    assertEquals(3, result.members().size()); // admin + user1 + user2
  }

  // The directory is graded along two axes — the caller's role and the team's toggle — so the
  // tests below are that matrix rather than one "non-admin is refused" case.

  @Test
  void getTeamMembers_asPlainMember_withDirectoryClosed_shouldThrow() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    queryContext.setUserForTest(user1);
    assertThrows(
        PedalonsException.class,
        () -> membershipService.getTeamMembers(team.getSlug(), 0, 10, null, null));
  }

  @Test
  void getTeamMembers_asPlainMember_withDirectoryOpen_shouldReturnEverything() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);
    dataService.setTeamEnableMemberDirectory(team, true);

    queryContext.setUserForTest(user1);
    MemberListResponse result = membershipService.getTeamMembers(team.getSlug(), 0, 10, null, null);

    assertEquals(2, result.members().size());
    assertTrue(result.members().stream().allMatch(m -> m.role() != null));
  }

  @Test
  void getTeamMembers_asNonMember_shouldThrowEvenWithDirectoryOpen() {
    dataService.setTeamEnableMemberDirectory(team, true);

    queryContext.setUserForTest(user1);
    assertThrows(
        PedalonsException.class,
        () -> membershipService.getTeamMembers(team.getSlug(), 0, 10, null, null));
  }

  /**
   * An organiser reads the roster whatever the team decided — they need candidates for a ride
   * group's leader, and {@code RideService} rejects a leader who is not a member. What a closed
   * directory withholds from them is the role and the join date, not the people.
   */
  @Test
  void getTeamMembers_asOrganizer_withDirectoryClosed_shouldReturnNamesOnly() {
    dataService.addUserToTeam(user1, team, TeamRole.ORGANIZER);

    queryContext.setUserForTest(user1);
    MemberListResponse result = membershipService.getTeamMembers(team.getSlug(), 0, 10, null, null);

    assertEquals(2, result.members().size());
    assertTrue(result.members().stream().allMatch(m -> m.role() == null));
    assertTrue(result.members().stream().allMatch(m -> m.joinedAt() == null));
    assertTrue(result.members().stream().allMatch(m -> m.user().displayName() != null));
  }

  /**
   * docs/LEDGER_*.md SEC-18: filtering on a role the response hides would hand the role back. The
   * filter is refused, not ignored, and the same filter stays open to whoever does get the roles.
   */
  @Test
  void getTeamMembers_roleFilter_isRefused_whenTheRolesAreHidden() {
    dataService.addUserToTeam(user1, team, TeamRole.ORGANIZER);

    queryContext.setUserForTest(user1);
    assertThrows(
        ForbiddenException.class,
        () -> membershipService.getTeamMembers(team.getSlug(), 0, 10, null, TeamRole.ADMIN));

    queryContext.setUserForTest(admin);
    MemberListResponse asAdmin =
        membershipService.getTeamMembers(team.getSlug(), 0, 10, null, TeamRole.ADMIN);
    assertEquals(1, asAdmin.members().size());
  }

  @Test
  void getTeamMembers_roleFilter_works_onceTheDirectoryIsOpen() {
    dataService.addUserToTeam(user1, team, TeamRole.ORGANIZER);
    dataService.setTeamEnableMemberDirectory(team, true);

    queryContext.setUserForTest(user1);
    MemberListResponse opened =
        membershipService.getTeamMembers(team.getSlug(), 0, 10, null, TeamRole.ADMIN);
    assertEquals(1, opened.members().size());
    assertEquals(TeamRole.ADMIN, opened.members().getFirst().role());
  }

  @Test
  void getTeamMembers_asOrganizer_withDirectoryOpen_shouldReturnRoles() {
    dataService.addUserToTeam(user1, team, TeamRole.ORGANIZER);
    dataService.setTeamEnableMemberDirectory(team, true);

    queryContext.setUserForTest(user1);
    MemberListResponse result = membershipService.getTeamMembers(team.getSlug(), 0, 10, null, null);

    assertTrue(result.members().stream().allMatch(m -> m.role() != null));
  }

  /**
   * The point of the whole exercise. {@code PublicUserDto} carries no address, so nothing leaks in
   * the body — but a search that matched on the e-mail would answer "is this address on this team?"
   * for any address one cares to type, which is an enumeration oracle over the entire domain.
   */
  @Test
  void getTeamMembers_searchByEmail_shouldFindNothingForANonAdmin() {
    dataService.addUserToTeam(user1, team, TeamRole.ORGANIZER);
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    queryContext.setUserForTest(user1);
    MemberListResponse result =
        membershipService.getTeamMembers(team.getSlug(), 0, 10, "user2@example.com", null);

    assertEquals(0, result.members().size());
    assertEquals(0, result.total());
  }

  @Test
  void getTeamMembers_searchByEmail_shouldStillWorkForAnAdmin() {
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    queryContext.setUserForTest(admin);
    MemberListResponse result =
        membershipService.getTeamMembers(team.getSlug(), 0, 10, "user2@example.com", null);

    assertEquals(1, result.members().size());
    assertEquals(user2.getId(), TsidUtils.toLong(result.members().getFirst().user().id()));
  }

  @Test
  void getTeamMembers_searchByName_shouldWorkForANonAdmin() {
    dataService.addUserToTeam(user1, team, TeamRole.ORGANIZER);
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    queryContext.setUserForTest(user1);
    MemberListResponse result =
        membershipService.getTeamMembers(team.getSlug(), 0, 10, "User Two", null);

    assertEquals(1, result.members().size());
  }

  @Test
  void getTeamMembers_shouldSupportPagination() {
    for (int i = 3; i <= 7; i++) {
      User user = dataService.createUser("user" + i + "@example.com", "User " + i);
      dataService.addUserToTeam(user, team, TeamRole.MEMBER);
    }

    queryContext.setUserForTest(admin);
    MemberListResponse result = membershipService.getTeamMembers(team.getSlug(), 0, 3, null, null);

    assertEquals(3, result.members().size());
    assertEquals(6, result.total()); // admin + 5 users
  }

  // ==================== Join Team ====================

  @Test
  void joinTeam_whenNotJoinable_shouldThrowForbidden() {
    dataService.setTeamJoinable(team, false);

    queryContext.setUserForTest(user1);
    PedalonsException ex =
        assertThrows(PedalonsException.class, () -> membershipService.joinTeam(team.getSlug()));
    assertEquals("FORBIDDEN", ex.getMessage());
  }

  @Test
  void joinTeam_shouldJoinPublicTeam() {
    queryContext.setUserForTest(user1);
    MemberDto result = membershipService.joinTeam(team.getSlug());

    assertNotNull(result);
    assertEquals(user1.getId(), TsidUtils.toLong(result.user().id()));
    assertEquals(TeamRole.MEMBER, result.role());
  }

  @Test
  void joinTeam_shouldThrowWhenAlreadyMember() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    queryContext.setUserForTest(user1);
    PedalonsException exception =
        assertThrows(PedalonsException.class, () -> membershipService.joinTeam(team.getSlug()));

    assertEquals("ALREADY_REGISTERED", exception.getMessage());
  }

  @Test
  void joinTeam_shouldAllowRejoinAfterDeletion() {
    UserTeam membership = dataService.addUserToTeam(user1, team, TeamRole.MEMBER);
    dataService.deleteUserTeam(membership);

    queryContext.setUserForTest(user1);
    MemberDto result = membershipService.joinTeam(team.getSlug());

    assertNotEquals(membership.getId(), TsidUtils.toLong(result.id()));
    assertEquals(TeamRole.MEMBER, result.role());
  }

  // ==================== Add Member ====================

  @Test
  void addMember_byATeamAdmin_isRefused() {
    // docs/LEDGER_*.md SEC-43: a team admin invites, and only the invitee's click lets them in.
    queryContext.setUserForTest(admin);
    assertThrows(
        ForbiddenException.class,
        () -> membershipService.addMember(team.getSlug(), user1.getId(), TeamRole.MEMBER));
  }

  @Test
  void addMember_shouldAddMemberAsPlatformAdmin() {
    User platformAdmin =
        dataService.createPlatformAdminUser("padmin@example.com", "Platform Admin");
    queryContext.setUserForTest(platformAdmin);
    MemberDto result =
        membershipService.addMember(team.getSlug(), user1.getId(), TeamRole.ORGANIZER);

    assertNotNull(result);
    assertEquals(user1.getId(), TsidUtils.toLong(result.user().id()));
    assertEquals(TeamRole.ORGANIZER, result.role());
  }

  @Test
  void addMember_shouldThrowForNonAdmin() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    queryContext.setUserForTest(user1);
    assertThrows(
        PedalonsException.class,
        () -> membershipService.addMember(team.getSlug(), user2.getId(), TeamRole.MEMBER));
  }

  @Test
  void addMember_shouldThrowWhenAlreadyMember() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    queryContext.setUserForTest(
        dataService.createPlatformAdminUser("padmin@example.com", "Platform Admin"));
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> membershipService.addMember(team.getSlug(), user1.getId(), TeamRole.ORGANIZER));

    assertEquals("ALREADY_REGISTERED", exception.getMessage());
  }

  @Test
  void addMember_shouldAllowReaddAfterDeletion() {
    UserTeam membership = dataService.addUserToTeam(user1, team, TeamRole.MEMBER);
    dataService.deleteUserTeam(membership);

    queryContext.setUserForTest(
        dataService.createPlatformAdminUser("padmin@example.com", "Platform Admin"));
    MemberDto result =
        membershipService.addMember(team.getSlug(), user1.getId(), TeamRole.ORGANIZER);

    assertNotEquals(membership.getId(), TsidUtils.toLong(result.id()));
    assertEquals(TeamRole.ORGANIZER, result.role());
  }

  // ==================== Update Member Role ====================

  @Test
  void updateMemberRole_shouldUpdateRole() {
    UserTeam membership = dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    queryContext.setUserForTest(admin);
    MemberDto result =
        membershipService.updateMemberRole(team.getSlug(), user1.getId(), TeamRole.ORGANIZER);

    assertEquals(membership.getId(), TsidUtils.toLong(result.id()));
    assertEquals(TeamRole.ORGANIZER, result.role());
  }

  @Test
  void updateMemberRole_shouldThrowForNonAdmin() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    queryContext.setUserForTest(user1);
    assertThrows(
        PedalonsException.class,
        () ->
            membershipService.updateMemberRole(team.getSlug(), user2.getId(), TeamRole.ORGANIZER));
  }

  @Test
  void updateMemberRole_shouldPreventDemotingLastAdmin() {
    queryContext.setUserForTest(admin);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () ->
                membershipService.updateMemberRole(team.getSlug(), admin.getId(), TeamRole.MEMBER));

    assertEquals("LAST_ADMIN", exception.getMessage());
  }

  @Test
  void updateMemberRole_shouldAllowDemotingWhenMultipleAdmins() {
    User admin2 = dataService.createUser("admin2@example.com", "Admin Two");
    dataService.addUserToTeam(admin2, team, TeamRole.ADMIN);

    queryContext.setUserForTest(admin2);
    MemberDto result =
        membershipService.updateMemberRole(team.getSlug(), admin.getId(), TeamRole.MEMBER);

    assertEquals(TeamRole.MEMBER, result.role());
  }

  // ==================== Remove Member ====================

  @Test
  void removeMember_shouldRemoveMemberAsAdmin() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    queryContext.setUserForTest(admin);
    membershipService.removeMember(team.getSlug(), user1.getId());

    queryContext.setUserForTest(user1);
    // Verify soft deletion by trying to get team - should not see it
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> adService.listAds(team.getSlug(), null, null, null, null, 0, 10));
    assertEquals("FORBIDDEN", exception.getMessage());
  }

  @Test
  void removeMember_shouldAllowSelfRemoval() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    queryContext.setUserForTest(admin);
    membershipService.removeMember(team.getSlug(), user1.getId());

    queryContext.setUserForTest(user1);
    // Verify soft deletion
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> adService.listAds(team.getSlug(), null, null, null, null, 0, 10));
    assertEquals("FORBIDDEN", exception.getMessage());
  }

  @Test
  void removeMember_shouldPreventRemovingLastAdmin() {
    queryContext.setUserForTest(admin);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> membershipService.removeMember(team.getSlug(), admin.getId()));

    assertEquals("LAST_ADMIN", exception.getMessage());
  }

  @Test
  void removeMember_shouldAllowRemovingWhenMultipleAdmins() {
    User admin2 = dataService.createUser("admin2@example.com", "Admin Two");
    dataService.addUserToTeam(admin2, team, TeamRole.ADMIN);

    queryContext.setUserForTest(admin2);
    membershipService.removeMember(team.getSlug(), admin.getId());

    queryContext.setUserForTest(admin);
    // Verify soft deletion
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> adService.listAds(team.getSlug(), null, null, null, null, 0, 10));
    assertEquals("FORBIDDEN", exception.getMessage());
  }

  @Test
  void removeMember_shouldThrowForNonAdminRemovingOthers() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    queryContext.setUserForTest(user1);
    assertThrows(
        PedalonsException.class,
        () -> membershipService.removeMember(team.getSlug(), user2.getId()));
  }

  // ==================== Leave Team ====================

  @Test
  void leaveTeam_shouldRemoveSelf() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    queryContext.setUserForTest(user1);
    membershipService.leaveTeam(team.getSlug());

    queryContext.setUserForTest(user1);
    // Verify soft deletion
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> adService.listAds(team.getSlug(), null, null, null, null, 0, 10));
    assertEquals("FORBIDDEN", exception.getMessage());
  }

  @Test
  void leaveTeam_shouldPreventLastAdminLeaving() {
    queryContext.setUserForTest(admin);
    PedalonsException exception =
        assertThrows(PedalonsException.class, () -> membershipService.leaveTeam(team.getSlug()));

    assertEquals("LAST_ADMIN", exception.getMessage());
  }

  // ==================== Business Rule Checks ====================

  @Test
  void requireNotLastAdmin_shouldSucceedWhenMultipleAdmins() {
    dataService.addUserToTeam(user1, team, TeamRole.ADMIN);
    UserTeam admin2 = dataService.addUserToTeam(user2, team, TeamRole.ADMIN);

    assertDoesNotThrow(() -> membershipService.requireNotLastAdmin(team, admin2));
  }

  @Test
  void requireNotLastAdmin_shouldSucceedForNonAdminRole() {
    dataService.addUserToTeam(user1, team, TeamRole.ADMIN);
    UserTeam member = dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    assertDoesNotThrow(() -> membershipService.requireNotLastAdmin(team, member));
  }

  @Test
  void requireNotLastAdmin_shouldThrowWhenLastAdmin() {
    UserTeam lastAdmin = dataService.addUserToTeam(user1, team, TeamRole.ADMIN);
    queryContext.setUserForTest(user1);
    membershipService.removeMember(team.getSlug(), admin.getId());

    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> membershipService.requireNotLastAdmin(this.team, lastAdmin));

    assertEquals("LAST_ADMIN", exception.getMessage());
  }

  @Test
  void requireNotLastAdminDemotion_shouldSucceedWhenMultipleAdmins() {
    dataService.addUserToTeam(user1, team, TeamRole.ADMIN);
    UserTeam admin2 = dataService.addUserToTeam(user2, team, TeamRole.ADMIN);

    assertDoesNotThrow(
        () -> membershipService.requireNotLastAdminDemotion(team, admin2, TeamRole.ORGANIZER));
  }

  @Test
  void requireNotLastAdminDemotion_shouldSucceedWhenNotDemotingFromAdmin() {
    UserTeam organizer = dataService.addUserToTeam(user1, team, TeamRole.ORGANIZER);

    assertDoesNotThrow(
        () -> membershipService.requireNotLastAdminDemotion(team, organizer, TeamRole.MEMBER));
  }

  @Test
  void requireNotLastAdminDemotion_shouldSucceedWhenPromotingToAdmin() {
    UserTeam admin = dataService.addUserToTeam(user1, team, TeamRole.ADMIN);

    assertDoesNotThrow(
        () -> membershipService.requireNotLastAdminDemotion(team, admin, TeamRole.ADMIN));
  }

  @Test
  void requireNotLastAdminDemotion_shouldThrowWhenDemotingLastAdmin() {
    UserTeam lastAdmin = dataService.addUserToTeam(user1, team, TeamRole.ADMIN);
    queryContext.setUserForTest(user1);
    membershipService.removeMember(team.getSlug(), admin.getId());

    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () ->
                membershipService.requireNotLastAdminDemotion(team, lastAdmin, TeamRole.ORGANIZER));

    assertEquals("LAST_ADMIN", exception.getMessage());
  }

  // ==================== Self-Action Checks ====================

  @Test
  void requireCanRemoveMember_shouldSucceedForSelfRemoval() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);

    assertDoesNotThrow(
        () -> membershipService.requireCanRemoveMember(user1, TeamRole.MEMBER, user1));
  }

  @Test
  void requireCanRemoveMember_shouldSucceedForAdminRemovingOthers() {
    dataService.addUserToTeam(user1, team, TeamRole.ADMIN);
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    assertDoesNotThrow(
        () -> membershipService.requireCanRemoveMember(user1, TeamRole.ADMIN, user2));
  }

  @Test
  void requireCanRemoveMember_shouldThrowForNonAdminRemovingOthers() {
    dataService.addUserToTeam(user1, team, TeamRole.MEMBER);
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> membershipService.requireCanRemoveMember(user1, TeamRole.MEMBER, user2));

    assertEquals("FORBIDDEN", exception.getMessage());
  }

  @Test
  void requireCanRemoveMember_shouldThrowForOrganizerRemovingOthers() {
    dataService.addUserToTeam(user1, team, TeamRole.ORGANIZER);
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);

    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> membershipService.requireCanRemoveMember(user1, TeamRole.ORGANIZER, user2));

    assertEquals("FORBIDDEN", exception.getMessage());
  }
}
