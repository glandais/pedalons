package fr.pedalons.common;

import java.util.Locale;
import org.jspecify.annotations.Nullable;

/**
 * E-mail addresses as the database keys them: trimmed and lower-cased.
 *
 * <p>Accounts and auth tokens are looked up by exact match, so an address stored with a capital
 * (an iPhone keyboard capitalises the first letter) could neither sign in nor receive a reset code
 * once typed in lower case — and the reply, identical for an unknown address, said nothing
 * (docs/LEDGER_*.md API-146). Every request DTO carrying an address normalises it on construction.
 */
public final class EmailAddresses {

  private EmailAddresses() {}

  public static @Nullable String normalize(@Nullable String email) {
    return email == null ? null : email.strip().toLowerCase(Locale.ROOT);
  }
}
