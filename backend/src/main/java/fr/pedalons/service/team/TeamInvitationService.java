package fr.pedalons.service.team;

import fr.pedalons.common.TokenUtils;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ConflictException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.InternalException;
import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamInvitation;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.teams.request.CreateInvitationRequest;
import fr.pedalons.dto.teams.response.InvitationPreviewDto;
import fr.pedalons.dto.teams.response.MemberDto;
import fr.pedalons.dto.teams.response.MyInvitationDto;
import fr.pedalons.dto.teams.response.MyInvitationListResponse;
import fr.pedalons.dto.teams.response.TeamInvitationDto;
import fr.pedalons.dto.teams.response.TeamInvitationListResponse;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.InvitationStatus;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.repository.team.TeamInvitationRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.limits.TeamMemberLimit;
import fr.pedalons.service.notification.NotificationPublisher;
import fr.pedalons.service.notification.event.TeamInvited;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * Invitations to join a team, addressed to an e-mail rather than to an account.
 *
 * <p>Two rules run through everything here.
 *
 * <p><b>Nobody joins a team without a click of their own.</b> Not the person who already has an
 * account, not the person who signs up because of the invitation. That is why acceptance needs a
 * session, why {@code AuthService} is untouched, and why signing up does not silently enrol anyone.
 *
 * <p><b>Creating an invitation must not say whether an account exists.</b> Same status, same body,
 * whichever branch runs; only the wording of the e-mail differs. Without that, anyone who
 * administers a team — including a team they created themselves a minute ago — has an
 * account-existence probe for the whole domain, which is precisely what {@code requestOtp},
 * {@code requestPasswordReset} and {@code requestEmailChange} each go out of their way to deny.
 */
@ApplicationScoped
public class TeamInvitationService {

  @Inject TeamInvitationRepository invitationRepository;

  @Inject UserTeamRepository userTeamRepository;

  @Inject UserRepository userRepository;

  @Inject TeamService teamService;

  @Inject TeamMembershipService membershipService;

  @Inject TeamMemberLimit memberLimit;

  @Inject TeamInvitationEmailService invitationEmailService;

  @Inject NotificationPublisher notificationPublisher;

  @Inject PedalonsQueryContext pedalonsContext;

  @ConfigProperty(name = "pedalons.teams.invitations.expiry-days", defaultValue = "14")
  int expiryDays;

  @ConfigProperty(name = "pedalons.teams.invitations.max-per-inviter-window", defaultValue = "20")
  int maxPerInviterWindow;

  @ConfigProperty(name = "pedalons.teams.invitations.inviter-window-minutes", defaultValue = "60")
  int inviterWindowMinutes;

  @ConfigProperty(name = "pedalons.teams.invitations.max-per-team-day", defaultValue = "50")
  int maxPerTeamDay;

  @ConfigProperty(name = "pedalons.teams.invitations.max-per-email-day", defaultValue = "5")
  int maxPerEmailDay;

  private static final int DAY_MINUTES = 24 * 60;

  // ---------------------------------------------------------------- administration

  /**
   * Sends an invitation, replacing any live one for the same address.
   *
   * <p>Re-inviting is not an error: the previous invitation is revoked and a fresh one issued. That
   * is the "resend" button, and making it a 409 with a separate resend endpoint would be two paths
   * for one intention — while still being rate-limited either way.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.CREATE)
  public TeamInvitationDto invite(String teamSlug, CreateInvitationRequest request) {
    Team team = teamService.getTeam(teamSlug);
    User inviter = pedalonsContext.getUser();

    if (!pedalonsContext.isPlatformAdmin() && !team.isAddMemberAllowed()) {
      throw new BusinessException(ErrorCode.TEAM_ADD_MEMBER_NOT_ALLOWED);
    }

    String email = normalize(request.email());
    TeamRole role = request.role() != null ? request.role() : TeamRole.MEMBER;

    if (email.equalsIgnoreCase(inviter.getEmail())) {
      throw new BusinessException(ErrorCode.TEAM_INVITE_SELF);
    }

    Long domainId = team.getDomain().getId();
    Optional<User> existing = userRepository.findByEmailAndDomain(domainId, email);
    if (existing.isPresent()
        && userTeamRepository.findByUserAndTeam(existing.get().getId(), team.getId()).isPresent()) {
      // Not an enumeration leak: an administrator can already search their own roster by e-mail.
      // Folding this into a uniform 201 would only produce invitations to people already there.
      throw new ConflictException(ErrorCode.TEAM_INVITE_ALREADY_MEMBER);
    }
    // Members and pending invitations together, so that every invitation sent can be accepted;
    // after the checks above, which name a more precise refusal (docs/LEDGER_*.md BILL-10).
    memberLimit.requireRoomForInvitation(team, email);

    enforceRateLimits(inviter, team, domainId, email);

    invitationRepository
        .findPendingByTeamAndEmail(team.getId(), email)
        .ifPresent(previous -> {
          previous.markRevoked(inviter);
          // The flush is load-bearing, and no test can prove it: Hibernate's action queue runs
          // inserts before updates, so without it the new PENDING row hits
          // uk_team_invitations_pending while the old one is still PENDING. Tests build the
          // schema from the JPA mappings, which cannot express a partial index, so this would
          // only ever fail in production.
          invitationRepository.flush();
        });

    String token = TokenUtils.generateSecureToken();
    TeamInvitation invitation =
        new TeamInvitation(
            inviter,
            team,
            email,
            role,
            TokenUtils.hashToken(token),
            Instant.now().plus(expiryDays, ChronoUnit.DAYS));
    invitationRepository.persist(invitation);
    // Queued whether or not an account holds the address: the dispatcher looks it up, off this
    // request, so nothing here differs between the two branches.
    notificationPublisher.publish(new TeamInvited(invitation.getId()), team, inviter);

    sendInvitationEmail(invitation, existing.orElse(null), token, domainId, email);

    return TeamInvitationDto.from(invitation);
  }

  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.CREATE)
  public TeamInvitationListResponse listInvitations(
      String teamSlug, int page, int size, InvitationStatus status) {
    Team team = teamService.getTeam(teamSlug);
    PedalonsPage<TeamInvitation> invitations =
        invitationRepository.findByTeam(team.getId(), page, size, status);
    List<TeamInvitationDto> dtos =
        invitations.items().stream().map(TeamInvitationDto::from).toList();
    return new TeamInvitationListResponse(dtos, invitations.total(), page, size);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.USER_TEAM, action = ActionType.CREATE)
  public void revoke(String teamSlug, String invitationId) {
    Team team = teamService.getTeam(teamSlug);
    Long id = TsidUtils.toLong(invitationId);
    TeamInvitation invitation =
        invitationRepository
            .findByIdOptional(id)
            .filter(i -> i.getTeam().getId().equals(team.getId()))
            .orElseThrow(() -> new NotFoundException(EntityType.USER_TEAM, id));

    if (!invitation.isPending()) {
      throw new ConflictException(ErrorCode.TEAM_INVITE_NOT_PENDING);
    }
    invitation.markRevoked(pedalonsContext.getUser());
  }

  // ---------------------------------------------------------------- the invitee's side

  /**
   * What the acceptance screen shows before anyone signs in. Public on purpose: an invitation opened
   * in a signed-out browser has to be able to say who is inviting and to what, or the page can only
   * offer a bare login form with no explanation of why.
   */
  @Public
  public InvitationPreviewDto preview(String token) {
    return InvitationPreviewDto.from(requireInvitation(token));
  }

  /**
   * Redeems an invitation for the signed-in user.
   *
   * <p>Never public. Accepting is consenting, and a consent attaches to an account; a public accept
   * that handed back a session would make the invitation link a login credential, and so make
   * intercepting one e-mail enough to take over an account.
   */
  @Logged
  @Transactional
  public MemberDto accept(String token) {
    return redeem(requireInvitation(token));
  }

  @Logged
  public MyInvitationListResponse listMine() {
    User user = pedalonsContext.getUser();
    List<MyInvitationDto> invitations =
        invitationRepository
            .findPendingForEmail(user.getDomain().getId(), normalize(user.getEmail()))
            .stream()
            // An invitation to a team they already belong to is noise, not an offer.
            .filter(i ->
                userTeamRepository.findByUserAndTeam(user.getId(), i.getTeam().getId()).isEmpty())
            .map(i -> MyInvitationDto.from(i, user.isPlatformAdmin()))
            .toList();
    return new MyInvitationListResponse(invitations);
  }

  @Logged
  @Transactional
  public MemberDto acceptMine(String invitationId) {
    Long id = TsidUtils.toLong(invitationId);
    TeamInvitation invitation =
        invitationRepository
            .findByIdOptional(id)
            .orElseThrow(() -> new NotFoundException(EntityType.USER_TEAM, id));
    return redeem(invitation);
  }

  // ---------------------------------------------------------------- internals

  /**
   * The one place an invitation turns into a membership, whether it came from a token or from the
   * signed-in user's own list.
   */
  private MemberDto redeem(TeamInvitation invitation) {
    User user = pedalonsContext.getUser();

    // Whoever holds the link is not necessarily who it was for. Checked before the state machine so
    // that a stranger cannot even learn whether the invitation is still live.
    if (!invitation.getEmail().equals(normalize(user.getEmail()))
        || !invitation.getDomainId().equals(user.getDomain().getId())) {
      throw new ForbiddenException(ErrorCode.TEAM_INVITE_EMAIL_MISMATCH);
    }
    // Otherwise signing up with someone else's address would be enough to capture their invitation.
    if (!user.isEmailVerified()) {
      throw new ForbiddenException(ErrorCode.EMAIL_NOT_VERIFIED);
    }

    Team team = invitation.getTeam();
    Optional<UserTeam> alreadyMember =
        userTeamRepository.findByUserAndTeam(user.getId(), team.getId());

    if (alreadyMember.isPresent()) {
      // Idempotent, deliberately. Replaying the link, or having joined in the meantime, leaves the
      // invitee exactly where they wanted to be — answering with an error would be telling someone
      // off for an outcome they already have. The existing role is never overwritten: an invitation
      // as MEMBER must not demote an ADMIN.
      if (invitation.isPending()) {
        invitation.markAccepted(user);
      }
      return MemberDto.from(alreadyMember.get());
    }

    requireRedeemable(invitation);

    // addMemberAllowed is *not* re-checked here. That flag guards the administrator's act of
    // inviting, not the invitee's consent; re-reading it would silently kill legitimate invitations
    // because of a platform-admin toggle, with a message the invitee could make no sense of. Same
    // for the inviter's role: an invitation is an act of the team, and the recourse if it should no
    // longer stand is for another admin to revoke it, which is explicit and visible.
    MemberDto member = membershipService.addMemberFromInvitation(team, user, invitation);
    invitation.markAccepted(user);
    return member;
  }

  private TeamInvitation requireInvitation(String token) {
    return invitationRepository
        .findByTokenHash(TokenUtils.hashToken(token))
        // A token that never existed and one the retention sweep removed are indistinguishable, so
        // they answer the same way.
        .orElseThrow(() -> new BusinessException(ErrorCode.TEAM_INVITE_INVALID));
  }

  /** Turns the stored state into the reason the caller cannot redeem, marking lapse on the way. */
  private void requireRedeemable(TeamInvitation invitation) {
    if (invitation.isLapsed()) {
      // accept()/acceptMine() are @Transactional and this throws right after: marking the entity
      // in memory would just get rolled back along with everything else. The row is expired in its
      // own transaction instead, so the mark survives even though the accept attempt fails.
      invitationRepository.markExpiredIndependently(invitation.getId());
      throw new BusinessException(ErrorCode.TEAM_INVITE_EXPIRED);
    }
    switch (invitation.getStatus()) {
      case PENDING -> {
        // redeemable
      }
      case EXPIRED -> throw new BusinessException(ErrorCode.TEAM_INVITE_EXPIRED);
      case REVOKED -> throw new BusinessException(ErrorCode.TEAM_INVITE_REVOKED);
      case ACCEPTED -> throw new BusinessException(ErrorCode.TEAM_INVITE_ALREADY_USED);
    }
  }

  private void enforceRateLimits(User inviter, Team team, Long domainId, String email) {
    long byInviter =
        invitationRepository.countRecentByCreator(inviter.getId(), inviterWindowMinutes);
    if (byInviter >= maxPerInviterWindow) {
      Log.warnf(
          "Invitation rate limit (inviter) hit: user=%d team=%d (%d in %d min)",
          inviter.getId(), team.getId(), byInviter, inviterWindowMinutes);
      throw new TooManyRequestsException(
          ErrorCode.TEAM_INVITE_RATE_LIMITED, Duration.ofMinutes(inviterWindowMinutes).toSeconds());
    }

    // Without this, two or three admins of one team simply add their individual quotas together.
    long byTeam = invitationRepository.countRecentByTeam(team.getId(), DAY_MINUTES);
    if (byTeam >= maxPerTeamDay) {
      Log.warnf("Invitation rate limit (team) hit: team=%d (%d in 24h)", team.getId(), byTeam);
      throw new TooManyRequestsException(
          ErrorCode.TEAM_INVITE_RATE_LIMITED, Duration.ofDays(1).toSeconds());
    }
  }

  /**
   * Sends the invitation, unless this address has already had its share today.
   *
   * <p>The per-address cap fails silently — the invitation is created, the admin sees it waiting,
   * only the mail is withheld. Answering 429 would tell administrator A that administrator B, of a
   * team A knows nothing about, has just invited the same person. {@code AuthService} makes the same
   * trade on its own rate limit, and for the same reason: the protection here is against one person
   * being bombarded by five clubs, not against the inviter.
   */
  private void sendInvitationEmail(
      TeamInvitation invitation, User recipient, String token, Long domainId, String email) {
    long byEmail = invitationRepository.countRecentByEmail(domainId, email, DAY_MINUTES);
    if (byEmail > maxPerEmailDay) {
      Log.warnf(
          "Invitation to %s withheld: %d already sent to this address in 24h", email, byEmail - 1);
      return;
    }

    try {
      invitationEmailService.sendInvitation(invitation, recipient, token);
    } catch (RuntimeException e) {
      // Rolls the whole thing back, which is the point: an invitation whose e-mail never left is
      // one nobody can act on, and it would sit in the admin's list looking sent while consuming a
      // slot in the (team, address) unique index. Also what keeps a missing mail template from
      // surfacing as an opaque 500.
      Log.errorf(
          e,
          "Invitation delivery failed for team=%d email=%s",
          invitation.getTeam().getId(),
          email);
      throw new InternalException(ErrorCode.TEAM_INVITE_DELIVERY_FAILED, e);
    }
  }

  private static String normalize(String email) {
    return email.trim().toLowerCase();
  }
}
