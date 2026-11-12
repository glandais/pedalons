package fr.pedalons.service.admin;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.admin.AdminTeamAttributesRequest;
import fr.pedalons.dto.admin.AdminTeamDto;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.TeamTier;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.security.annotation.Admin;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class AdminTeamService {

  @Inject TeamRepository teamRepository;

  @Inject UserTeamRepository userTeamRepository;

  /**
   * Every team, archived ones included: the screen marks them « Archivée » and offers to restore
   * them — which it could never do while they were filtered out, leaving the API as the only way
   * back.
   */
  @Admin
  public PedalonsPage<AdminTeamDto> listTeams(
      @Nullable String domainId, @Nullable TeamTier tier, int page, int size) {
    List<String> clauses = new ArrayList<>();
    List<Object> values = new ArrayList<>();
    if (domainId != null) {
      values.add(TsidUtils.toLong(domainId));
      clauses.add("domain.id = ?" + values.size());
    }
    // The free teams, to find the one to unlock (docs/LEDGER_*.md BILL-10).
    if (tier != null) {
      values.add(tier);
      clauses.add("tier = ?" + values.size());
    }
    String query = clauses.isEmpty() ? "1 = 1" : String.join(" and ", clauses);
    Object[] params = values.toArray();

    List<Team> teams =
        teamRepository
            .find(query + " order by createdAt desc, id desc", params)
            .page(page, size)
            .list();
    long total = teamRepository.count(query, params);

    List<AdminTeamDto> items =
        teams.stream()
            .map(team -> {
              long memberCount = userTeamRepository.count("team.id = ?1", team.getId());
              return AdminTeamDto.from(team, memberCount);
            })
            .toList();

    return new PedalonsPage<>(items, total);
  }

  @Admin
  public AdminTeamDto getTeam(String teamId) {
    // An archived team is still shown to the platform admin, who may restore it.
    Team team = findTeamIncludingDeleted(teamId);
    long memberCount = userTeamRepository.count("team.id = ?1", team.getId());
    return AdminTeamDto.from(team, memberCount);
  }

  @Admin
  @Transactional
  public AdminTeamDto updateTeamAttributes(String teamId, AdminTeamAttributesRequest request) {
    Team team = findTeam(teamId);
    team.setVisibilityEditable(request.visibilityEditable());
    team.setJoinable(request.joinable());
    team.setAddMemberAllowed(request.addMemberAllowed());
    team.setEnableRoutePlanner(request.enableRoutePlanner());
    if (request.publicContentAllowed() != null) {
      team.setPublicContentAllowed(request.publicContentAllowed());
    }
    if (request.tier() != null) {
      team.setTier(request.tier());
    }
    String tierNote = request.tierNote();
    if (tierNote != null) {
      team.setTierNote(tierNote.isBlank() ? null : tierNote.strip());
    }
    teamRepository.persist(team);
    long memberCount = userTeamRepository.count("team.id = ?1", team.getId());
    return AdminTeamDto.from(team, memberCount);
  }

  @Admin
  @Transactional
  public AdminTeamDto toggleTeamDeleted(String teamId) {
    Team team = findTeamIncludingDeleted(teamId);
    // Toggle soft-delete
    team.setDeleted(!team.isDeleted());
    teamRepository.persist(team);
    long memberCount = userTeamRepository.count("team.id = ?1", team.getId());
    return AdminTeamDto.from(team, memberCount);
  }

  private Team findTeam(String teamId) {
    Long id = TsidUtils.toLong(teamId);
    return teamRepository
        .find("id = ?1 and deleted = false", id)
        .firstResultOptional()
        .orElseThrow(() -> new NotFoundException(ErrorCode.TEAM_NOT_FOUND));
  }

  private Team findTeamIncludingDeleted(String teamId) {
    Long id = TsidUtils.toLong(teamId);
    return teamRepository
        .find("id = ?1", id)
        .firstResultOptional()
        .orElseThrow(() -> new NotFoundException(ErrorCode.TEAM_NOT_FOUND));
  }
}
