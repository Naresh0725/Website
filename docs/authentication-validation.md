# Authentication validation — PASS

Date: 5 October 2026 (Asia/Kolkata)
Branch: authentication-user-accounts
Tested source commit: 726f46be9dbd83bd1c264ebd7449be8766430885
CI: https://github.com/Naresh0725/Website/actions/runs/37229275292
Job: https://github.com/Naresh0725/Website/actions/runs/37229275292/job/111515314574

## Results

- Native PostgreSQL 17.11; Node 22; GitHub-hosted Ubuntu.
- TypeScript application typecheck: PASS.
- Full suite: **55 passed, 0 failed, 0 skipped**.
- All 30 previously approved database/concurrency tests remain passing.
- 25 added authentication/security tests pass.

Coverage: registration/password validation, generic duplicate-account/recovery responses, verified-email login, encrypted token storage and cookie flags, CSRF/origin protection, profile isolation, logout during provider outages and account suspension, session fixation prevention, exact expiry, idle expiry, database rate limiting, recovery-only sessions and reset revocation, email-token replay rejection, Google state/PKCE and replay/expiry checks, MFA step-up/session rotation, permission/audit enforcement, preservation of free-attempt limits, actual SDK PKCE generation and MFA response contracts, ciphertext tampering, account-page CSP/script syntax, malformed requests, and native concurrent refresh.

The concurrent refresh test sends 12 authenticated requests against separate pooled PostgreSQL connections and asserts one provider refresh-token rotation.

## Fixes verified

- MFA provider response uses expires_in; adapter derives expires_at without an unsafe type cast.
- Logout deletes the opaque browser session even when the account is suspended.
- Session creation and both deadlines share one timestamp. A microsecond difference between independent clock reads had violated the strict 24-hour check in a native CI run; migration 006 fixes this without weakening the constraint.

## Important test boundary

Application endpoints and database operations were tested against real PostgreSQL with a controlled authentication provider substitute. Actual Supabase SDK PKCE and MFA-response contracts were also tested using simulated provider HTTP responses. These are not live Google-consent, real-email-delivery, or deployed Supabase end-to-end tests.

Live provider verification remains pending a new project's Supabase/SMTP/Google OAuth configuration and deployment host. No credentials from another project were inspected or reused. See authentication.md for exact setup and endpoints.

Only account/authentication pages and APIs were built. No exam/question features, mock-test UI, dashboard, payment UI or later-phase implementation was added. No production deployment or merge to main was performed. Await approval before the next phase.
