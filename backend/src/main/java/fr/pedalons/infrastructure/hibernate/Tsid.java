package fr.pedalons.infrastructure.hibernate;

import static java.lang.annotation.ElementType.FIELD;
import static java.lang.annotation.ElementType.METHOD;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.hibernate.annotations.IdGeneratorType;

/**
 * Generates a TSID as a {@code Long} identifier. Replaces hypersistence-utils' {@code @Tsid} with
 * the same semantics, see {@link TsidGenerator}.
 */
@IdGeneratorType(TsidGenerator.class)
@Retention(RetentionPolicy.RUNTIME)
@Target({FIELD, METHOD})
public @interface Tsid {}
