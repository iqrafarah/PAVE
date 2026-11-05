# Authentication

Web and iOS use Supabase Auth with the same rules. A change to this file is a shared change (see `Conventions.md`).

## Sign in

1. The user signs in with the email and password supplied by their organization (`signInWithPassword`). There is no self sign-up.
2. Two-step verification with an authenticator app (TOTP) is mandatory for every user. After the password step the session is `aal1`; only an `aal2` session may use the app.

## Two-step verification (TOTP)

Decide the next screen after the password step with `mfa.getAuthenticatorAssuranceLevel()` and `mfa.listFactors()`:

| Situation | `currentLevel` | Verified TOTP factor | Screen |
|-----------|----------------|----------------------|--------|
| Fully signed in | `aal2` | yes | App home |
| Returning user | `aal1` | yes | Verify: enter the 6-digit code (`mfa.challengeAndVerify`) |
| First sign-in | `aal1` | no | Setup: `mfa.enroll({ factorType: 'totp' })`, show the QR code and the secret as text, then confirm with `mfa.challengeAndVerify`, then a "You're all set" screen |

Rules:

- Before enrolling, remove unverified TOTP factors of the user (`mfa.unenroll`). They are left behind when a setup is abandoned and block a new one.
- Wrong or expired code message: "This code is invalid or has expired. Use the latest code in your authenticator app and try again."
- "Back to login" on the setup and verify screens signs the user out.
- If the MFA status cannot be loaded, treat the user as not verified (fail closed).
- Codes come only from the authenticator app, never by email or SMS.

## Forgot password

A password reset uses the email address and a code from the authenticator app. **No email is sent.** Users without a verified authenticator cannot reset their password themselves and contact IT support.

### Step 1: verify (`verify-password-reset-code`)

The user enters their email and the 6-digit authenticator code. The app calls the Edge Function with `{ email, code }`. The user is not logged in.

The function blocks the email after 5 failed attempts in 15 minutes, reads the user's verified TOTP secret and checks the code (30-second steps, 1 step clock drift allowed). If correct, it returns a one-time reset token: `{ "resetToken": "..." }`. The token is valid for 10 minutes and works once. Only its SHA-256 hash is stored.

Keep the token in memory only (never in the URL, storage or logs).

### Step 2: new password (`reset-password`)

The user chooses a new password (twice). The app calls the Edge Function with `{ resetToken, password }`. The function checks the password rules, uses up the token, sets the password and revokes all sessions of the user (signed out on every device). Then show "Wachtwoord gewijzigd".

### Responses

Failures return JSON `{ "error": "<code>" }`.

| Function | Status | `error` | Meaning |
|----------|--------|---------|---------|
| verify | 200 | – | `{ "resetToken": "..." }` |
| verify | 400 | `invalid_credentials` | Unknown email, no authenticator, or wrong code. Deliberately the same, so nobody can find out which emails have an account |
| verify | 429 | `too_many_attempts` | Too many failed attempts, wait 15 minutes |
| reset | 200 | – | `{ "ok": true }` |
| reset | 400 | `weak_password` | Password does not meet the rules (the token is not used up) |
| reset | 400 | `invalid_token` | Token missing, expired or already used. Start again at step 1 |
| both | 500 | `server_error` | Something went wrong on the server |

Security note: the email address is not secret, so this reset is only as strong as the user's phone. Anyone with the unlocked phone can reset the password. This was a deliberate product decision.

### Files and deploy

- Edge Functions: `shared/supabase/functions/verify-password-reset-code/`, `shared/supabase/functions/reset-password/` (shared helpers in `_shared/`)
- Migration (attempt counter, reset tokens, helper functions): `shared/supabase/migrations/20261105130000_password_reset_with_authenticator.sql`

After the migration is applied:

```bash
supabase functions deploy verify-password-reset-code --no-verify-jwt
supabase functions deploy reset-password --no-verify-jwt
```

`--no-verify-jwt` is needed because the user is not logged in when they reset their password.

## Password rules

- At least 12 characters
- Uppercase and lowercase letters
- At least one digit and one symbol

The apps only show these rules; Supabase must enforce them (see dashboard settings).

## Supabase dashboard settings

These are shared settings. Change them only after agreeing with both teams.

| Setting | Where | Value |
|---------|-------|-------|
| MFA TOTP | Authentication → Multi-Factor | Enabled |
| Minimum password length | Authentication → Providers → Email | 12 |
| Password requirements | Authentication → Providers → Email | Lowercase, uppercase letters, digits and symbols |
| SMTP | Authentication → SMTP Settings | Own SMTP server before real users (needed for the sign-up confirmation email; the built-in sender is heavily rate limited) |

## Lost authenticator app

The user contacts their organization's IT support. An admin removes the user's TOTP factor in the Supabase dashboard (Authentication → Users → user → MFA factors). At the next sign-in the user goes through the setup again.

## Enforcement

- App routing (web middleware, iOS navigation) only decides which screen to show.
- The real protection is RLS: every table with user data gets a restrictive policy using `public.is_mfa_verified()` (migration `shared/supabase/migrations/20261105120000_require_mfa_aal2.sql`). Do not apply these policies until iOS supports two-step verification, or iOS users lose access to their data.
