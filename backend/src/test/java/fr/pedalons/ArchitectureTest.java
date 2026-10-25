package fr.pedalons;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noMethods;

import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaField;
import com.tngtech.archunit.core.domain.JavaMethod;
import com.tngtech.archunit.core.domain.JavaMethodCall;
import com.tngtech.archunit.core.domain.JavaModifier;
import com.tngtech.archunit.core.domain.JavaPackage;
import com.tngtech.archunit.core.domain.JavaParameter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;
import fr.pedalons.domain.common.NotNullableDbValue;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.service.security.annotation.Admin;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import jakarta.persistence.*;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Context;
import java.lang.reflect.AnnotatedType;
import java.lang.reflect.Field;
import java.util.HashSet;
import java.util.Optional;
import java.util.Set;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.jboss.resteasy.reactive.RestForm;
import org.jspecify.annotations.NullMarked;
import org.jspecify.annotations.Nullable;

@AnalyzeClasses(packages = "fr.pedalons", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

  @ArchTest
  static final ArchRule no_jackson_2 =
      noClasses()
          .that()
          .resideInAPackage("fr.pedalons..")
          .should()
          .dependOnClassesThat()
          .resideInAnyPackage(
              "com.fasterxml.jackson.core..",
              "com.fasterxml.jackson.databind..",
              "com.fasterxml.jackson.datatype..",
              "com.fasterxml.jackson.module..")
          .because(
              "Quarkus 4 only produces a Jackson 3 JsonMapper; Jackson 2 is still on the classpath"
                  + " through flyway/magika/timeshape, so the compiler would not catch it"
                  + " (docs/LEDGER_*.md API-144)");

  @ArchTest
  static final ArchRule packages_with_classes_should_be_null_marked =
      classes()
          .should(beInPackageAnnotatedWithNullMarked())
          .because("all packages with classes must be annotated with @NullMarked for null safety");

  @ArchTest
  static final ArchRule entities_should_have_no_args_constructor =
      classes()
          .that()
          .areAnnotatedWith(Entity.class)
          .should(haveNoArgsConstructor())
          .because("Hibernate requires a no-args constructor for entity instantiation");

  @ArchTest
  static final ArchRule entity_fields_should_have_proper_nullability_annotations =
      classes()
          .that()
          .areAnnotatedWith(Entity.class)
          .or()
          .areAnnotatedWith(MappedSuperclass.class)
          .should(haveProperNullabilityAnnotationsOnFields())
          .because(
              "nullable database fields must be annotated with @Nullable, "
                  + "non-null fields must NOT be annotated with @Nullable");

  @ArchTest
  static final ArchRule schema_annotated_types_should_have_validate_schema =
      classes()
          .that()
          .areAnnotatedWith(Schema.class)
          .should()
          .beAnnotatedWith(ValidateSchema.class)
          .because("all @Schema annotated types must have @ValidateSchema for validation");

  @ArchTest
  static final ArchRule api_calls_to_service_must_have_check_access =
      classes()
          .that()
          .resideInAPackage("fr.pedalons.api..")
          .should(onlyCallServiceMethodsWithCheckAccess())
          .because(
              "all API calls to service methods must go through @CheckAccess annotated methods");

  /**
   * The transaction boundary is the service method (docs/LEDGER_*.md AUD-14): every resource method
   * calls a single {@code @Transactional} service method, so a second annotation on the resource
   * only widened the transaction around the response building. A resource that ever needs several
   * service calls to be atomic should get one service method that does them, not a resource-level
   * transaction.
   */
  @ArchTest
  static final ArchRule resources_should_not_be_transactional =
      noClasses()
          .that()
          .resideInAPackage("fr.pedalons.api..")
          .should()
          .beAnnotatedWith(jakarta.transaction.Transactional.class)
          .because("the transaction boundary is the service method");

  @ArchTest
  static final ArchRule resource_methods_should_not_be_transactional =
      noMethods()
          .that()
          .areDeclaredInClassesThat()
          .resideInAPackage("fr.pedalons.api..")
          .should()
          .beAnnotatedWith(jakarta.transaction.Transactional.class)
          .because("the transaction boundary is the service method");

  @ArchTest
  static final ArchRule api_layer_should_only_access_allowed_packages =
      classes()
          .that()
          .resideInAPackage("fr.pedalons.api..")
          .should()
          .onlyDependOnClassesThat()
          .resideInAnyPackage(
              "fr.pedalons.api..",
              "fr.pedalons.common..",
              "fr.pedalons.dto..",
              "fr.pedalons.service..",
              "fr.pedalons.enums..",
              "java..",
              "jakarta..",
              "org.eclipse.microprofile..",
              "org.jboss.resteasy.reactive..",
              "org.jspecify..")
          .because(
              "API layer should only access common, dto, service and enums packages, not domain or"
                  + " infrastructure");

  @ArchTest
  static final ArchRule request_body_parameters_should_have_valid_annotation =
      classes()
          .that()
          .resideInAPackage("fr.pedalons.api..")
          .and()
          .areAnnotatedWith(Path.class)
          .should(haveValidAnnotationOnRequestBodyParameters())
          .because("request body parameters must be annotated with @Valid for validation");

  private static ArchCondition<JavaClass> haveValidAnnotationOnRequestBodyParameters() {
    return new ArchCondition<>("have @Valid annotation on request body parameters") {
      @Override
      public void check(JavaClass javaClass, ConditionEvents events) {
        for (JavaMethod method : javaClass.getMethods()) {
          // Only check methods that are REST endpoints (have HTTP method annotations)
          if (!isRestEndpoint(method)) {
            continue;
          }

          for (JavaParameter parameter : method.getParameters()) {
            // Skip parameters that are not request bodies
            if (isJaxRsAnnotatedParameter(parameter)) {
              continue;
            }

            // Skip primitive types and common non-DTO types
            if (isPrimitiveOrCommonType(parameter)) {
              continue;
            }

            // Check if parameter has @Valid annotation
            if (!parameter.isAnnotatedWith(Valid.class)) {
              String message =
                  String.format(
                      "Method %s.%s() has request body parameter '%s' of type '%s' without @Valid"
                          + " annotation",
                      javaClass.getSimpleName(),
                      method.getName(),
                      parameter.getIndex(),
                      parameter.getRawType().getSimpleName());
              events.add(SimpleConditionEvent.violated(javaClass, message));
            }
          }
        }
      }

      private boolean isRestEndpoint(JavaMethod method) {
        return method.isAnnotatedWith(GET.class)
            || method.isAnnotatedWith(POST.class)
            || method.isAnnotatedWith(PUT.class)
            || method.isAnnotatedWith(DELETE.class)
            || method.isAnnotatedWith(PATCH.class);
      }

      private boolean isJaxRsAnnotatedParameter(JavaParameter parameter) {
        return parameter.isAnnotatedWith(PathParam.class)
            || parameter.isAnnotatedWith(QueryParam.class)
            || parameter.isAnnotatedWith(HeaderParam.class)
            || parameter.isAnnotatedWith(CookieParam.class)
            || parameter.isAnnotatedWith(MatrixParam.class)
            || parameter.isAnnotatedWith(FormParam.class)
            || parameter.isAnnotatedWith(BeanParam.class)
            || parameter.isAnnotatedWith(Context.class)
            || parameter.isAnnotatedWith(RestForm.class);
      }

      private boolean isPrimitiveOrCommonType(JavaParameter parameter) {
        String typeName = parameter.getRawType().getName();
        return typeName.startsWith("java.")
            || typeName.startsWith("jakarta.ws.rs.")
            || typeName.startsWith("jakarta.servlet.")
            || typeName.startsWith("org.jboss.resteasy.");
      }
    };
  }

  private static ArchCondition<JavaClass> onlyCallServiceMethodsWithCheckAccess() {
    return new ArchCondition<>("only call service methods annotated with @CheckAccess") {
      @Override
      public void check(JavaClass apiClass, ConditionEvents events) {
        for (JavaMethodCall call : apiClass.getMethodCallsFromSelf()) {
          JavaClass targetClass = call.getTargetOwner();
          String targetPackage = targetClass.getPackageName();

          // Only check calls to fr.pedalons.service..
          if (!targetPackage.startsWith("fr.pedalons.service.")) {
            continue;
          }

          // Get the resolved target method
          Optional<JavaMethod> resolvedMethod = call.getTarget().resolveMember();
          if (resolvedMethod.isEmpty()) {
            continue;
          }

          JavaMethod targetMethod = resolvedMethod.get();

          // Check if method or its declaring class has @CheckAccess
          boolean hasCheckAccess =
              targetMethod.isAnnotatedWith(Admin.class)
                  || targetMethod.isAnnotatedWith(CheckAccess.class)
                  || targetMethod.isAnnotatedWith(Logged.class)
                  || targetMethod.isAnnotatedWith(Public.class);

          if (!hasCheckAccess) {
            String message =
                String.format(
                    "Method %s.%s() in API class %s calls service method %s.%s() which is not"
                        + " annotated with @Admin/@CheckAccess/@Logged/@Public",
                    call.getOriginOwner().getSimpleName(),
                    call.getOrigin().getName(),
                    apiClass.getSimpleName(),
                    targetClass.getSimpleName(),
                    targetMethod.getName());
            events.add(SimpleConditionEvent.violated(apiClass, message));
          }
        }
      }
    };
  }

  private static ArchCondition<JavaClass> haveNoArgsConstructor() {
    return new ArchCondition<>("have a no-args constructor") {
      @Override
      public void check(JavaClass javaClass, ConditionEvents events) {
        boolean hasNoArgsConstructor =
            javaClass.getConstructors().stream().anyMatch(c -> c.getRawParameterTypes().isEmpty());

        if (!hasNoArgsConstructor) {
          events.add(
              SimpleConditionEvent.violated(
                  javaClass,
                  String.format(
                      "Entity '%s' does not have a no-args constructor required by Hibernate",
                      javaClass.getSimpleName())));
        }
      }
    };
  }

  private static ArchCondition<JavaClass> beInPackageAnnotatedWithNullMarked() {
    return new ArchCondition<>("be in a package annotated with @NullMarked") {
      private final Set<String> checkedPackages = new HashSet<>();

      @Override
      public void check(JavaClass javaClass, ConditionEvents events) {
        JavaPackage javaPackage = javaClass.getPackage();
        String packageName = javaPackage.getName();

        if (checkedPackages.contains(packageName)) {
          return;
        }
        checkedPackages.add(packageName);

        boolean hasNullMarked = javaPackage.isAnnotatedWith(NullMarked.class);

        if (!hasNullMarked) {
          String message =
              String.format(
                  "Package '%s' contains classes but is not annotated with @NullMarked",
                  packageName);
          events.add(SimpleConditionEvent.violated(javaClass, message));
        }
      }
    };
  }

  private static ArchCondition<JavaClass> haveProperNullabilityAnnotationsOnFields() {
    return new ArchCondition<>("have proper nullability annotations on fields") {
      @Override
      public void check(JavaClass javaClass, ConditionEvents events) {
        for (JavaField field : javaClass.getFields()) {
          // A constant is not a column.
          if (field.getModifiers().contains(JavaModifier.STATIC)) {
            continue;
          }
          boolean nullable = isNullable(field);
          boolean hasNullableAnnotation = hasNullableTypeAnnotation(field);
          if (nullable && !hasNullableAnnotation) {
            events.add(
                SimpleConditionEvent.violated(
                    field,
                    String.format(
                        "Field '%s' in '%s' is nullable in database but not annotated with"
                            + " @Nullable",
                        field.getName(), javaClass.getSimpleName())));
          }
          if (!nullable && hasNullableAnnotation) {
            events.add(
                SimpleConditionEvent.violated(
                    field,
                    String.format(
                        "Field '%s' in '%s' is NOT nullable in database but is annotated with"
                            + " @Nullable",
                        field.getName(), javaClass.getSimpleName())));
          }
        }
      }
    };
  }

  enum Nullability {
    NOT_NULL_USER,
    NOT_NULL_JPA,
    NULLABLE
  }

  private static boolean isNullable(JavaField field) {
    // Skip fields with auto-generated values
    if (field.isAnnotatedWith(CreationTimestamp.class)
        || field.isAnnotatedWith(UpdateTimestamp.class)
        || field.isAnnotatedWith(Version.class)
        || field.isAnnotatedWith(Id.class)
        || field.isAnnotatedWith(OneToMany.class)) {
      return false;
    }

    if (field.isAnnotatedWith(NotNullableDbValue.class)) {
      return false;
    }

    if (field.isAnnotatedWith(ManyToOne.class)) {
      Optional<JoinColumn> joinColumn = field.tryGetAnnotationOfType(JoinColumn.class);
      if (joinColumn.isEmpty()) {
        return true;
      }
      return joinColumn.get().nullable();
    }
    Optional<Column> column = field.tryGetAnnotationOfType(Column.class);
    if (column.isEmpty()) {
      return true;
    }
    return column.get().nullable();
  }

  private static boolean hasNullableTypeAnnotation(JavaField javaField) {
    // Check field-level annotation first
    if (javaField.isAnnotatedWith(Nullable.class)) {
      return true;
    }

    // Check TYPE_USE annotation on the field's type using reflection
    try {
      Field reflectField = javaField.reflect();
      AnnotatedType annotatedType = reflectField.getAnnotatedType();
      return annotatedType.isAnnotationPresent(Nullable.class);
    } catch (Exception e) {
      // Fallback: can't reflect, assume no annotation
      return false;
    }
  }
}
