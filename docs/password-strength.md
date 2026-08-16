# Password strength policy

This document is the single source of truth for the password strength policy that any implementation setting an account password must satisfy.
It lives here, rather than in `vibetype` or `postgraphile`, because both services implement it independently (code sharing between them is not an option), and a policy shared across services belongs in `stack` rather than being duplicated per repo.
When either service's implementation changes, check it against this document rather than against the other service's code.

## Scope

Applies to every operation that sets a password a user will authenticate with:

| Operation               | Field carrying the new password | Covered |
| ------------------------ | -------------------------------- | ------- |
| `accountRegistration`    | `input.password`                 | yes     |
| `accountPasswordReset`   | `input.password`                 | yes     |
| `accountPasswordChange`  | `input.passwordNew`              | yes     |

`accountPasswordChange`'s `input.passwordCurrent` is explicitly **out of scope**: it authenticates an existing password, which may predate this policy, and must never be strength-checked.

## Requirements

Both of the following must hold.

1. **Minimum length**: 8 characters.
   This matches NIST SP 800-63B's own floor.
   It is a cheap sanity backstop, not the control doing the real work, see [Why keep a length floor](#why-keep-a-length-floor).
2. **Minimum strength**: a [zxcvbn](https://github.com/zxcvbn-ts/zxcvbn) score of at least 3 ("safely unguessable", resists an offline, slow-hash attack; see the library's own scoring guidance).
   This is the control that actually determines whether a password is accepted in practice.

### Why keep a length floor

NIST SP 800-63B requires a minimum length (>= 8) plus screening against common or compromised passwords.
It does not separately mandate a guessability-estimator score on top of that.
zxcvbn's score already factors in length as one of its inputs, so once score >= 3 is required, an 8 character floor rarely does independent work: empirically, the shortest fully random password (e.g. `xK9#mL2qP`, drawn from a large character set) needed to reach score 3 is 9 characters, one above this floor.
The floor is kept anyway as a structural backstop that does not depend on zxcvbn's heuristics being correct for a given input, and as a small margin against future improvements in offline hash-cracking speed, which erode a short password's safety margin fastest regardless of how patternless it is.

## Algorithm and configuration

Both implementations must use identical configuration, or they will disagree on borderline passwords (a password accepted by the client but rejected by the server, or vice versa).

- **Library**: `@zxcvbn-ts/core`, via `new ZxcvbnFactory(options).check(password).score`.
- **Dictionaries**: `@zxcvbn-ts/language-common` (common passwords plus adjacency graphs for keyboard-pattern detection) merged with `@zxcvbn-ts/language-de` and `@zxcvbn-ts/language-en` (both dictionaries only; German and English are the platform's supported locales).
- **Translations**: `@zxcvbn-ts/language-en`.
  This only affects zxcvbn's internal feedback strings.
  Neither implementation surfaces them to the user, so the specific language here is not user-visible, but the `ZxcvbnFactory` constructor requires a non-empty value.
- **Package versions**: pinned independently in each repo's `package.json`.
  Keep `@zxcvbn-ts/core`, `@zxcvbn-ts/language-common`, `@zxcvbn-ts/language-de`, and `@zxcvbn-ts/language-en` at the same version in both repos.
  A dictionary update can change which side of the score-3 boundary a given password falls on.

## Current implementation status

| Layer                          | Minimum length (8) | zxcvbn score (>= 3) |
| ------------------------------- | -------------------- | --------------------- |
| `vibetype` (client)             | enforced, all 3 operations | enforced, all 3 operations |
| `postgraphile` (server)         | not this layer's job, see below | enforced, all 3 operations |
| `sqitch` (database)             | enforced, all 3 operations (`char_length(...) < 8` in each function) | not applicable, zxcvbn cannot run in SQL |

`postgraphile` intentionally does not re-check length: since every underlying sqitch function already rejects anything shorter than 8 characters, and that is exactly this policy's floor, duplicating the check in `postgraphile` would add no protection.

## Where each side implements this

- `vibetype`: `src/app/utils/passwordStrength.ts` (scoring), `src/app/utils/validation.ts` (`SCHEMA_PASSWORD_V2`, length), `src/app/composables/useAuthPasswordValidation.ts` and `usePasswordPairValidation.ts` (live field validation wiring).
- `postgraphile`: `src/presets/passwordStrength.ts` (`PasswordStrengthPlugin`, a Grafserv middleware that inspects `accountRegistration`, `accountPasswordReset`, and `accountPasswordChange` mutations before they execute).
- `sqitch`: the `char_length(...) < 8` check in `function_account_registration.sql`, `function_account_password_reset.sql`, and `function_account_password_change.sql`.
