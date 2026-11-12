package fr.pedalons.service.team;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ConflictException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.domain.team.*;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.teams.response.MemberDto;
import fr.pedalons.dto.teams.response.MemberListResponse;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.MemberSortBy;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.infrastructure.exception.*;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.limits.TeamMemberLimit;
import fr.pedalons.service.security.Context;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.CheckAccess;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class TeamMembershipService {

  @Inject UserTeamRepository userTeamRepository;

  @Inject UserRepository userRepository;

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject TeamService teamService;

  @Inject TeamMemberLimit memberLimit;

  /**
   * The team's roster, graded by what the caller is entitled to see.
   *
   * <p>Two things vary, and neither is a filter on the rows themselves — every caller who gets past
   * {@link UserTeamAccessChecker} sees the same members:
   *
   * <ul>
   *   <li><b>What {@code search} matches.</b> Only an administrator searches by e-mail. The address
   *       is in no response — {@code PublicUserDto} does not carry it — but a search that matches on
   *       it answers "is this address on this team?" for any address one cares to type, which is an
   *       enumeration oracle over the whole domain. Restricting the clause to the display name is
   *       what makes opening this endpoint safe at all.
   *   <li><b>Whether {@code role} and {@code joinedAt} are filled.</b> They are, for an
   *       administrator, and for everyone once the team has opened its directory. An organiser on a
   *       team that has <i>not</i> opened it still gets the list — they need it to designate a ride
   *       group's leader — but only the names, and a {@code role} filter is refused (403): it would
   *       reveal the roles the response hides.
   * </ul>
   */
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.LIST)
  public MemberListResponse getTeamMembers(
      String teamSlug, int page, int size, String search, TeamRole role) {
    return getTeamMembers(teamSlug, page, size, search, role, null, null);
  }

  /**
   * Same, ordered.
   *
   * @param sortBy {@link MemberSortBy#JOINED_AT} is refused (403) to a caller who does not get the
   *     join dates, for the reason the role filter is: the order would hand them back. Null is
   *     {@link MemberSortBy#NAME}, which everyone who reaches this list may have: it is made of the
   *     names the response carries anyway.
   * @param sortDir null is the key's default — A to Z for the name, newest first for the join date
   */
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.LIST)
  public MemberListResponse getTeamMembers(
      String teamSlug,
      int page,
      int size,
      @Nullable String search,
      @Nullable TeamRole role,
      @Nullable MemberSortBy sortBy,
      @Nullable SortDirection sortDir) {
    Team team = teamService.getTeam(teamSlug);
    // A platform admin never reaches the access checker (SecurityVerifier short-circuits it), so
    // the "is this caller an admin" question has to be asked again here rather than inferred from
    // having got this far.
    TeamRole callerRole = pedalonsContext.getContext(team).teamRole();
    boolean admin =
        pedalonsContext.isPlatformAdmin() || (callerRole != null && callerRole.isAdmin());
    boolean full = admin || team.isEnableMemberDirectory();
    // Filtering on a role the response hides would hand it back all the same, one query per role.
    // Refused like every other thing this caller may not do, rather than ignored: an ignored filter
    // reads as an answer. docs/LEDGER_*.md SEC-18.
    if ((role != null || sortBy == MemberSortBy.JOINED_AT) && !full) {
      throw new ForbiddenException();
    }

    PedalonsPage<UserTeam> members =
        userTeamRepository.findByTeam(
            team.getId(), page, size, search, role, admin, sortBy, sortDir);
    List<MemberDto> dtos = members.items().stream().map(m -> MemberDto.from(m, full)).toList();
    return new MemberListResponse(dtos, members.total(), page, size);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.JOIN)
  public MemberDto joinTeam(String teamSlug) {
    Team team = teamService.getTeam(teamSlug);
    return doAddMember(team, TeamRole.MEMBER, pedalonsContext.getUser());
  }

  @Transactional
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.CREATE)
  public MemberDto addMember(String teamSlug, Long targetUserId, TeamRole role) {
    Team team = teamService.getTeam(teamSlug);
    User actingUser = pedalonsContext.getUser();
    boolean isPlatformAdmin = actingUser.isPlatformAdmin();
    if (!isPlatformAdmin && !team.isAddMemberAllowed()) {
      throw new BusinessException(ErrorCode.TEAM_ADD_MEMBER_NOT_ALLOWED);
    }
    // An account of another site is a stranger here, and answered as one: the same 404 as an id
    // that exists nowhere (docs/LEDGER_*.md SEC-12, audit L6).
    User targetUser =
        userRepository
            .findActiveByIdAndDomain(pedalonsContext.getDomainId(), targetUserId)
            .orElseThrow(() -> new NotFoundException(EntityType.USER, targetUserId));

    return doAddMember(team, role, targetUser);
  }

  /**
   * Creates the membership an accepted invitation earns.
   *
   * <p>Not {@code doAddMember}: the membership's {@code createdBy} is the person who invited, not
   * the person who accepted, so a roster can still answer "who brought this member in" long after
   * the fact. No authorization of its own — the token the invitee redeemed <em>is</em> the
   * authorization, and {@code TeamInvitationService} has already established that it is theirs and
   * still live.
   */
  @Transactional
  public MemberDto addMemberFromInvitation(Team team, User user, TeamInvitation invitation) {
    // An invitation sent under the cap may still find the team full: others came in meanwhile.
    memberLimit.requireRoomForMember(team);
    UserTeam membership = new UserTeam(invitation.getCreatedBy(), user, team, invitation.getRole());
    userTeamRepository.persist(membership);
    return MemberDto.from(membership);
  }

  private MemberDto doAddMember(Team team, TeamRole role, User user) {
    User creator = pedalonsContext.getUser();
    // Check for existing membership
    Optional<UserTeam> existingMembership =
        userTeamRepository.findByUserAndTeam(user.getId(), team.getId());

    if (existingMembership.isPresent()) {
      throw new ConflictException(ErrorCode.ALREADY_REGISTERED);
    }
    // The tier's cap, after the flags: a closed team says so rather than that it is full
    // (docs/LEDGER_*.md BILL-10).
    memberLimit.requireRoomForMember(team);

    // Create new membership
    UserTeam membership = new UserTeam(creator, user, team, role);
    userTeamRepository.persist(membership);

    return MemberDto.from(membership);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.UPDATE)
  public MemberDto updateMemberRole(String teamSlug, Long targetUserId, TeamRole newRole) {
    Team team = teamService.getTeam(teamSlug);
    UserTeam targetMembership =
        userTeamRepository
            .findByUserAndTeam(targetUserId, team.getId())
            .orElseThrow(() -> new NotFoundException(EntityType.USER_TEAM, targetUserId));

    requireNotLastAdminDemotion(team, targetMembership, newRole);

    targetMembership.setRole(newRole);
    userTeamRepository.persist(targetMembership);

    return MemberDto.from(targetMembership);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.DELETE)
  public void removeMember(String teamSlug, Long targetUserId) {
    Team team = teamService.getTeam(teamSlug);
    doRemoveMember(team, targetUserId);
  }

  private void doRemoveMember(Team team, Long targetUserId) {
    Context context = pedalonsContext.getContext(team);
    User actingUser = context.user();
    TeamRole teamRole = context.teamRole();
    User targetUser =
        userRepository
            .findActiveByIdAndDomain(pedalonsContext.getDomainId(), targetUserId)
            .orElseThrow(() -> new NotFoundException(EntityType.USER, targetUserId));
    requireCanRemoveMember(actingUser, teamRole, targetUser);

    UserTeam targetMembership =
        userTeamRepository
            .findByUserAndTeam(targetUser.getId(), team.getId())
            .orElseThrow(() -> new NotFoundException(EntityType.USER_TEAM, targetUserId));

    requireNotLastAdmin(team, targetMembership);

    userTeamRepository.delete(targetMembership);
  }

  void requireCanRemoveMember(User actor, TeamRole teamRole, User target) {
    boolean isSelfRemoval = target.getId().equals(actor.getId());
    if (isSelfRemoval) {
      // Users can always remove themselves (leave the team)
      return;
    }
    // Non-self removal requires admin rights
    if (teamRole == null || !teamRole.isAdmin()) {
      throw new ForbiddenException();
    }
  }

  void requireNotLastAdmin(Team team, UserTeam targetMembership) {
    if (targetMembership.getRole() == TeamRole.ADMIN) {
      long adminCount = userTeamRepository.countAdminsByTeam(team.getId());
      if (adminCount <= 1) {
        throw new BusinessException(ErrorCode.LAST_ADMIN);
      }
    }
  }

  void requireNotLastAdminDemotion(Team team, UserTeam targetMembership, TeamRole newRole) {
    if (targetMembership.getRole() == TeamRole.ADMIN && newRole != TeamRole.ADMIN) {
      requireNotLastAdmin(team, targetMembership);
    }
  }

  @Transactional
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.LEAVE)
  public void leaveTeam(String teamSlug) {
    Team team = teamService.getTeam(teamSlug);
    doRemoveMember(team, pedalonsContext.getUserId());
  }
}
