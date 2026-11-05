# Authentication

Web and iOS use Supabase Auth with the same rules. A change to this file is a shared change (see `Conventions.md`).

## Sign in

1. The user signs in with their email and password (`signInWithPassword`). Accounts are created by an admin in the Supabase dashboard; there is no self sign-up. Users who need help contact PAVE-support (contact@pave.com).
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

A reset needs a 6-digit code sent by email and, if the account has a verified authenticator, a code from the authenticator app. Supabase only allows a password change at `aal2` for accounts with a verified authenticator, so the email code alone is not enough for them.

1. The user enters their email. Call `resetPasswordForEmail(email)` without `redirectTo`. Always show the same message, whether or not the email has an account: "Als er een account bestaat voor dit e-mailadres, hebben we een code gestuurd."
2. The user types the 6-digit code from the email. Call `verifyOtp({ email, token, type: 'recovery' })`. The session is now `aal1`.
3. Check the factors with `mfa.listFactors()`:
   - verified TOTP factor: show the verify screen and confirm the authenticator code with `mfa.challengeAndVerify`. The session is now `aal2`.
   - no verified factor: go straight to step 4 (`aal2` is not possible without a factor).
4. The user chooses a new password (twice), checked against the password rules below. Call `updateUser({ password })`.
5. Web continues to the app. iOS signs out and shows "Wachtwoord gewijzigd".

Error codes to handle:

| Code | When | Message |
|------|------|---------|
| `over_email_send_rate_limit` | A new email code was requested within 60 seconds | "Je hebt net al een code aangevraagd. Wacht 60 seconden en probeer het opnieuw." |
| `otp_expired` | Wrong or expired email code | "Deze code klopt niet of is verlopen. Vraag een nieuwe code aan." |
| `mfa_verification_failed` | Wrong or expired authenticator code | "Deze code klopt niet of is verlopen. Gebruik de nieuwste code uit je authenticator-app en probeer het opnieuw." |
| `insufficient_aal` | Password change without `aal2` on an account with an authenticator | "Bevestig eerst met een code uit je authenticator-app dat jij het bent." |
| `same_password` | New password equals the current one | "Dit is je huidige wachtwoord. Kies een ander wachtwoord." |
| `weak_password` | Password does not meet the rules | "Je wachtwoord voldoet nog niet aan alle eisen." |

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
| Email OTP length | Authentication → Providers → Email | 6 |
| Reset Password email template | Authentication → Email Templates → Reset Password | Shows the code `{{ .Token }}`, no link |
| SMTP | Authentication → SMTP Settings | Own SMTP server before real users (needed for the reset code and the sign-up confirmation email; the built-in sender is heavily rate limited). The sender address must be on a domain verified with the SMTP provider |

## Lost authenticator app

The user contacts PAVE-support (contact@pave.com). An admin removes the user's TOTP factor in the Supabase dashboard (Authentication → Users → user → MFA factors). At the next sign-in the user goes through the setup again.

## Enforcement

- App routing (web middleware, iOS navigation) only decides which screen to show.
- The real protection is RLS: every table with user data gets a restrictive policy using `public.is_mfa_verified()` (migration `shared/supabase/migrations/20261105120000_require_mfa_aal2.sql`). Do not apply these policies until iOS supports two-step verification, or iOS users lose access to their data.
