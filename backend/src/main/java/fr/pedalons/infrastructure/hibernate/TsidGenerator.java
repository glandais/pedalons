package fr.pedalons.infrastructure.hibernate;

import io.hypersistence.tsid.TSID;
import java.util.EnumSet;
import org.hibernate.engine.spi.SharedSessionContractImplementor;
import org.hibernate.generator.BeforeExecutionGenerator;
import org.hibernate.generator.EventType;
import org.hibernate.generator.EventTypeSets;
import org.jspecify.annotations.Nullable;

/**
 * Identifier generator behind {@link Tsid}. Never give this class a CDI scope: Hibernate
 * instantiates it through its default constructor.
 */
public final class TsidGenerator implements BeforeExecutionGenerator {

  // Exactly hypersistence's Tsid.FactorySupplier: one factory for every entity of the JVM,
  // 10 node bits drawn at random unless TSID_NODE / tsid.node is set.
  private static final TSID.Factory FACTORY =
      TSID.Factory.builder().withRandomFunction(TSID.Factory.THREAD_LOCAL_RANDOM_FUNCTION).build();

  @Override
  public Object generate(
      SharedSessionContractImplementor session,
      @Nullable Object owner,
      @Nullable Object currentValue,
      EventType eventType) {
    return FACTORY.generate().toLong();
  }

  @Override
  public EnumSet<EventType> getEventTypes() {
    return EventTypeSets.INSERT_ONLY;
  }
}
