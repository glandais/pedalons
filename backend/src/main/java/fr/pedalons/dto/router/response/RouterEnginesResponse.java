package fr.pedalons.dto.router.response;

import fr.pedalons.dto.router.request.RouterEngine;
import fr.pedalons.dto.router.request.RouterProfile;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

public record RouterEnginesResponse(
    @Schema(
            required = true,
            description =
                "The engines the planner can ask for a leg. STADIA is always there, with every"
                    + " profile; PEDALONS only when the service behind it is configured and says it"
                    + " is ready")
        List<RouterEngineOffer> engines) {

  /** One engine and the profiles it calculates; the others go to Stadia whatever the request says. */
  public record RouterEngineOffer(
      @Schema(required = true) RouterEngine engine,
      @Schema(required = true) List<RouterProfile> profiles) {}
}
