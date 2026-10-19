package fr.pedalons.domain.route;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import fr.pedalons.common.planner.PlannerState;
import java.io.Serializable;

/**
 * A planner state as stored in the {@code planner_state} JSONB column of a track or a preview
 * (docs/LEDGER_*.md WEB-100, C4a). Not part of the contract.
 *
 * @param trackRevision the revision of the track the state was written with: the {@code file_id} of
 *     the route's original GPX, or the {@code files_revision} of a preview. Set by the server, never
 *     read from a client. A state is only read back while it equals the current revision of the
 *     track, so a save that bypassed the state (an older release, a file) leaves it stale.
 */
// The JSONB column is read by hypersistence's own ObjectMapper, which fails on unknown
// properties: a release must read a state written by a later one (rolling deploy, rollback).
@JsonIgnoreProperties(ignoreUnknown = true)
public record PlannerStateDocument(long trackRevision, PlannerState state) implements Serializable {

  public PlannerStateDocument withTrackRevision(long revision) {
    return new PlannerStateDocument(revision, state);
  }
}
