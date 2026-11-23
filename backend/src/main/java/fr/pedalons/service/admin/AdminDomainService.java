package fr.pedalons.service.admin;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.dto.admin.AdminActivationResponse;
import fr.pedalons.dto.admin.AdminActivationWeekDto;
import fr.pedalons.dto.admin.AdminDomainDto;
import fr.pedalons.dto.admin.AdminStatsDto;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.repository.platform.ActivationStatsRepository;
import fr.pedalons.repository.platform.DomainRepository;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.security.annotation.Admin;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.List;

@ApplicationScoped
public class AdminDomainService {

  @Inject DomainRepository domainRepository;

  @Inject TeamRepository teamRepository;

  @Inject UserRepository userRepository;

  @Inject ActivationStatsRepository activationStatsRepository;

  /** At most a year of sign-up weeks. */
  static final int MAX_ACTIVATION_WEEKS = 52;

  /**
   * Activation of new accounts per sign-up week and domain (docs/LEDGER_*.md API-213), the
   * current week and the {@code weeks - 1} before it. {@code weeks} is clamped to [1, 52]. A week
   * is {@code complete} once its last possible account has had its 7 days, i.e. 14 days after
   * its Monday: until then its counts can still grow.
   */
  @Admin
  public AdminActivationResponse getActivation(int weeks) {
    return activation(weeks, Instant.now());
  }

  AdminActivationResponse activation(int weeks, Instant now) {
    int weeksBack = Math.clamp(weeks, 1, MAX_ACTIVATION_WEEKS);
    LocalDate today = LocalDate.ofInstant(now, ZoneOffset.UTC);
    LocalDate firstMonday =
        today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)).minusWeeks(weeksBack - 1L);
    List<AdminActivationWeekDto> rows =
        activationStatsRepository
            .weeklyActivation(firstMonday.atStartOfDay(ZoneOffset.UTC).toInstant())
            .stream()
            .map(r ->
                new AdminActivationWeekDto(
                    TsidUtils.toString(r.domainId()),
                    r.domainName(),
                    r.weekStart(),
                    !r.weekStart().plusDays(14).isAfter(today),
                    r.signedUp(),
                    r.verified(),
                    r.joinedTeam(),
                    r.joinedRide()))
            .toList();
    return new AdminActivationResponse(rows, weeksBack);
  }

  @Admin
  public AdminStatsDto getStats() {
    long totalDomains = domainRepository.count("deleted = false");
    long totalTeams = teamRepository.count("deleted = false");
    long totalUsers = userRepository.count("deleted = false");
    return new AdminStatsDto(totalDomains, totalTeams, totalUsers);
  }

  @Admin
  public PedalonsPage<AdminDomainDto> listDomains(int page, int size) {
    List<Domain> domains =
        domainRepository
            .find("deleted = false order by createdAt desc, id desc")
            .page(page, size)
            .list();
    long total = domainRepository.count("deleted = false");

    List<AdminDomainDto> items =
        domains.stream()
            .map(domain -> {
              long teamCount =
                  teamRepository.count("domain.id = ?1 and deleted = false", domain.getId());
              long userCount =
                  userRepository.count("domain.id = ?1 and deleted = false", domain.getId());
              return AdminDomainDto.from(domain, teamCount, userCount);
            })
            .toList();

    return new PedalonsPage<>(items, total);
  }

  @Admin
  public AdminDomainDto getDomain(String domainId) {
    Domain domain = findDomain(domainId);
    long teamCount = teamRepository.count("domain.id = ?1 and deleted = false", domain.getId());
    long userCount = userRepository.count("domain.id = ?1 and deleted = false", domain.getId());
    return AdminDomainDto.from(domain, teamCount, userCount);
  }

  @Admin
  @Transactional
  public AdminDomainDto createDomain(
      String domainName,
      String name,
      String baseUrl,
      boolean singleTeam,
      boolean enableGpxPlanner,
      String androidFingerprints) {
    Domain domain = new Domain(domainName, name, baseUrl);
    domain.setSingleTeam(singleTeam);
    domain.setEnableGpxPlanner(enableGpxPlanner);
    domain.setAndroidFingerprints(androidFingerprints);
    domainRepository.persist(domain);
    return AdminDomainDto.from(domain, 0, 0);
  }

  @Admin
  @Transactional
  public AdminDomainDto updateDomain(
      String domainId,
      String name,
      String baseUrl,
      boolean singleTeam,
      boolean enableGpxPlanner,
      String androidFingerprints) {
    Domain domain = findDomain(domainId);
    domain.setName(name);
    domain.setBaseUrl(baseUrl);
    domain.setSingleTeam(singleTeam);
    domain.setEnableGpxPlanner(enableGpxPlanner);
    domain.setAndroidFingerprints(androidFingerprints);
    domainRepository.persist(domain);
    long teamCount = teamRepository.count("domain.id = ?1 and deleted = false", domain.getId());
    long userCount = userRepository.count("domain.id = ?1 and deleted = false", domain.getId());
    return AdminDomainDto.from(domain, teamCount, userCount);
  }

  @Admin
  @Transactional
  public AdminDomainDto toggleDomainActive(String domainId) {
    Domain domain = findDomain(domainId);
    domain.setActive(!domain.isActive());
    domainRepository.persist(domain);
    long teamCount = teamRepository.count("domain.id = ?1 and deleted = false", domain.getId());
    long userCount = userRepository.count("domain.id = ?1 and deleted = false", domain.getId());
    return AdminDomainDto.from(domain, teamCount, userCount);
  }

  private Domain findDomain(String domainId) {
    Long id = TsidUtils.toLong(domainId);
    return domainRepository
        .find("id = ?1 and deleted = false", id)
        .firstResultOptional()
        .orElseThrow(NotFoundException::new);
  }
}
