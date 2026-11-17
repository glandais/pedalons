package fr.pedalons.service.asset;

import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.common.ContentVisibilityRules;
import fr.pedalons.service.security.AccessChecker;
import fr.pedalons.service.security.Context;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.SecurityVerifier;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.Response;
import java.util.List;

@ApplicationScoped
public class AssetAccessChecker implements AccessChecker {

  @Inject AssetRepository assetRepository;

  @Inject SecurityVerifier securityVerifier;

  @Inject PedalonsQueryContext pedalonsContext;

  @Override
  public EntityType getType() {
    return EntityType.ASSET;
  }

  @Override
  public boolean hasRights(ActionType action, List<Object> params) {

    Context context = pedalonsContext.getContext(params);
    Team team = context.team();
    User user = context.user();
    TeamRole teamRole = context.teamRole();

    return switch (action) {
      case CREATE -> teamRole != null;
      case READ, UPDATE, DELETE -> {
        Long assetId = pedalonsContext.getParam(params, 1);
        if (assetId == null) {
          yield false;
        }
        Asset asset = assetRepository.findByIdOptional(assetId).orElse(null);
        if (asset == null) {
          yield false;
        }
        // The asset must belong to the team the URL names, which was resolved on this site (slug
        // redirects included): the id alone reached any site's asset, and the role checked below
        // is the caller's role in the URL's team (docs/LEDGER_*.md SEC-12, audit L5).
        if (team == null || !asset.getTeam().getId().equals(team.getId())) {
          yield false;
        }
        team = asset.getTeam();
        TeamEntity teamEntity = asset.getTeamEntity();
        if (teamEntity == null) {
          // Asset not yet attached to entity - only organizers can see/modify
          yield user != null
              && teamRole != null
              && asset.getCreatedBy().getId().equals(user.getId());
        }
        // The logo of a private team that publishes by link: readable by anyone, since its public
        // content embeds it (TeamPublicationDto.logoUrl). The logo only — Team.logoAssetId, the
        // formula that DTO reads — never the rest of the about page. Read off the team already
        // loaded: no query, members and open teams included (docs/LEDGER_*.md API-176).
        if (action == ActionType.READ
            && ContentVisibilityRules.privateTeamLogoIsPublic(team)
            && asset.getId().equals(team.getLogoAssetId())) {
          yield true;
        }
        // The caller may touch the asset only if they may read the content holding it.
        if (!canReadHolder(team, teamEntity)) {
          yield false;
        }
        if (action == ActionType.READ) {
          yield true;
        }
        // UPDATE/DELETE require organizer
        yield teamRole != null && teamRole.isOrganizer();
      }
      case LIST, LIST_ALL_TEAMS, JOIN, LEAVE -> false;
    };
  }

  /**
   * Whether the caller may read the content an asset is attached to. The content's checker answers
   * 404 for content hidden from the caller (its {@code findBySlug} filters in SQL), while an asset
   * that does not exist, belongs to another team or is not attached answers 403: the status told an
   * asset held by hidden content apart from no asset at all. Hidden content is therefore a refusal
   * like the others — one status, whatever the reason (docs/LEDGER_*.md SEC-51).
   */
  private boolean canReadHolder(Team team, TeamEntity teamEntity) {
    try {
      return securityVerifier.canAccess(
          teamEntity.getEntityType(),
          ActionType.READ,
          // we always expect slug as first parameter for team entities
          List.of(team.getSlug(), teamEntity.getSlug()));
    } catch (PedalonsException e) {
      // Both NotFoundException classes (common and infrastructure) end up here.
      if (e.getStatus() == Response.Status.NOT_FOUND) {
        return false;
      }
      throw e;
    }
  }
}
