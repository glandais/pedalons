package fr.pedalons.service.asset;

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
        // User can read asset if he has rights to see related entity
        securityVerifier.verifyAccess(
            teamEntity.getEntityType(),
            ActionType.READ,
            // we always expect slug as first parameter for team entities
            List.of(team.getSlug(), teamEntity.getSlug()));
        if (action == ActionType.READ) {
          yield true;
        }
        // UPDATE/DELETE require organizer
        yield teamRole != null && teamRole.isOrganizer();
      }
      case LIST, LIST_ALL_TEAMS, JOIN, LEAVE -> false;
    };
  }
}
