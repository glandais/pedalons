package fr.pedalons.infrastructure.hibernate;

import com.fasterxml.jackson.databind.JsonNode;
import org.hibernate.type.descriptor.java.MutableMutabilityPlan;

/**
 * Copies a {@link JsonNode} with {@code deepCopy()}. Hibernate's default copy is a JSON round trip,
 * which turns a {@code LongNode(5)} into an {@code IntNode(5)}; the node then compares unequal to
 * its snapshot and the row is rewritten on every flush. Put it on every {@code JsonNode} column.
 */
public final class JsonNodeMutabilityPlan extends MutableMutabilityPlan<JsonNode> {

  @Override
  protected JsonNode deepCopyNotNull(JsonNode value) {
    return value.deepCopy();
  }
}
