# Authentication and User Accounts

This phase adds account-only pages and an HTTP service. It does not expose exam, question, attempt, payment, analytics or dashboard routes.

## Implemented flows

- `/auth`: registration, login, forgot-password, Google login, profile editing, current-device and all-device logout.
- `/auth/confirm`: explicit user confirmation of signup/recovery links; never consumes a token simply because an email scanner requests the URL.
- Password reset uses a short-lived **recovery-only** session. It cannot read a profile, start a test, or change roles. Successful reset revokes all local account sessions and requests provider-wide signout.
- Default role `student`; profile edits cannot set user IDs, roles or permissions. Role changes require a database-authorized account administrator, a verified MFA session and an audit reason. Self-role changes are prohibited.
- TOTP enrollment and verification endpoints make the administrator MFA requirement usable; verification rotates the opaque session cookie.

## Server architecture

`src/server.ts` provides the Node HTTP service. `src/auth/api.ts` enforces request, CSRF, identity and scope checks. `src/auth/provider.ts` integrates the official Supabase client. `src/auth/store.ts` uses the restricted `exam_auth` database role. Migration `005_authentication.sql` creates sessions, OAuth flow state, durable rate limits and security events; adds student/account-admin roles; and leaves the existing two-free-attempt balance intact.

Provider passwords are sent only to Supabase Auth and are never stored by this application. The SDK is instantiated per operation, using server-side memory/storage, with automatic refresh disabled. The database session lock coordinates refresh across application instances.

## Required independent configuration

No live provider account or credentials were supplied, and no unrelated project credentials were reused. To connect a new deployment:

1. Use a **new** Supabase project; apply all five migrations and `db/deployment/supabase_identity.sql`.
2. Create separate migration and runtime credentials. The auth server login receives `GRANT exam_auth TO <auth_login>` only; never use the database owner or Supabase service-role key to serve requests.
3. Set the variables in `.env.example`, including HTTPS `APP_ORIGIN`, `AUTH_DATABASE_URL`, new-project Supabase URL and publishable key, and a 32-byte random encryption key.
4. Enable email/password authentication and email confirmation. Enable suitable provider password policy and production SMTP. Confirmation is intentionally required even if a provider accidentally returns an unverified session.
5. Set Supabase Site URL to APP_ORIGIN. Allow the exact auth redirect paths for this new host; Google callback must permit the generated `state` query parameter. Do not allow arbitrary external redirect hosts.
6. Configure the email templates with token hashes:
   - Signup: `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=signup`
   - Recovery: `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=recovery`
7. Create Google OAuth credentials for this project, configure Google's authorized callback to the **Supabase auth callback URL**, and enable the Google provider in Supabase. Supabase then redirects to the application's browser-bound PKCE callback. Use only openid/email/profile scopes.
8. Terminate HTTPS at a trusted reverse proxy, forwarding to the service bound to loopback. `npm ci`, `npm run migrate` with migration credentials, then `npm start` with auth credentials. Cookies are always Secure; direct HTTP is intentionally not an authentication deployment.

Provider setup references:
- https://supabase.com/docs/guides/auth/social-login/auth-google
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/guides/auth/sessions

## Routes

All mutating JSON requests require the exact configured Origin and `Content-Type: application/json`. Session-authenticated mutations additionally require `X-CSRF-Token` matching the session-bound CSRF token (also provided in the Secure CSRF cookie). The origin is deployment-configured and is never derived from Host/X-Forwarded headers.

| Route | Method | Purpose |
|---|---|---|
| `/health` | GET | Auth service liveness |
| `/auth`, `/auth/confirm` | GET | Account-only pages |
| `/auth/register` | POST | email/password registration, generic confirmation response |
| `/auth/login` | POST | password login and fresh session |
| `/auth/logout` | POST | `{all:false}` current device or `{all:true}` all local sessions |
| `/auth/forgot-password` | POST | generic recovery email response |
| `/auth/verify` | POST | one-time `{token_hash,type:signup|recovery}` verification |
| `/auth/reset-password` | POST | new password; recovery session and CSRF required |
| `/auth/google` | POST | return provider authorization URL; establish short-lived flow cookie |
| `/auth/google/callback` | GET | validate browser-bound state, consume flow once, exchange PKCE code; redirect to `/auth` |
| `/auth/session` | GET | current account profile/roles/permissions |
| `/account/profile` | GET/PATCH | read/update own profile only |
| `/account/roles` | POST | audited administrator role grant/revoke |
| `/auth/mfa/enroll` | POST | authenticated TOTP enrollment; returns secret for secure enrollment display |
| `/auth/mfa/verify` | POST | `{factor_id,code}`; verifies MFA and rotates session |

Profile PATCH accepts only display_name, preferred_language and timezone. Registration accepts only email and password; it never trusts provider user metadata for authorization.

## Session and security policy

- Browser gets a fresh random 256-bit `__Host-exam_session` cookie: Secure, HttpOnly, SameSite=Lax, Path=/, no Domain. No provider bearer/refresh token or password enters browser storage or API responses.
- Only SHA-256 of the opaque session identifier is stored. Provider tokens are authenticated-encrypted using AES-256-GCM and a server-only random key. Rotating/removing that key intentionally invalidates existing encrypted sessions; plan key rotation operationally.
- Account sessions: maximum 24 hours, idle timeout 30 minutes. Recovery sessions: maximum 10 minutes. Server/database time enforces expiry. Successful sign-in and MFA verification replace the previous browser session identifier.
- Each authenticated request verifies the provider identity and local active-account status. Roles/permissions are read from PostgreSQL, not stale client claims. Verified provider identity is bound to the local session user ID.
- Refresh takes place under a database row lock; simultaneous requests cannot independently rotate the same refresh token.
- Origin + session-bound CSRF checks protect mutations including logout. Login and Google-start also require the configured Origin, preventing cross-site login initiation.
- OAuth state is 256-bit random, tied to an HttpOnly cookie, encrypted server-side PKCE storage, single-use and 10-minute expiry. No user-controlled post-login redirect is accepted.
- Generic registration/recovery responses avoid explicit account enumeration. Shared PostgreSQL counters rate-limit both peer/path and account/path. The Node server ignores spoofable forwarding headers. Behind a proxy, all clients share the proxy IP rate bucket until a reviewed trusted-proxy configuration is introduced; this is conservative and may limit legitimate traffic.
- Auth-only HTML uses a fresh nonce CSP, no third-party assets, no-referrer and no-store headers. Email token hashes are removed from browser history once read; visible text uses textContent.
- Password reset and all-device logout revoke local sessions. Provider-wide signout is best-effort after local revocation, so provider outages do not prevent app logout. SDK/provider responses and secrets are never logged. Generic errors include only an opaque correlation ID.
- Auth server role cannot directly read session tables, private answer keys, payment records or mutate free-attempt balances. It can only call its narrowly granted functions.

## First administrator

Bootstrap one reviewed account_admin assignment using migration-owner access as an audited operator procedure; never add a public bootstrap endpoint or a hardcoded administrator email. An operator should insert the selected role assignment and an admin_audit_logs record in one transaction. Enroll/verify TOTP using the authenticated MFA endpoints before using role-management APIs. No account has been bootstrapped here.

## Operations and limits

Run a scheduled owner-maintenance job to remove expired auth_sessions/auth_flows and expired auth_rate_limits. Retain security/audit events under an explicit privacy-retention policy. Apply provider-side rate limiting/CAPTCHA and production monitoring before public launch.

Provider network calls and local database writes cannot form one distributed transaction. A lost response during a password/provider update can require re-login or another recovery link; do not treat an uncertain response as a successful login. In particular, a database failure after remote password change requires incident review/revocation before restoring service. This phase is not a production deployment.

## Validation boundary

The tests exercise the real PostgreSQL migrations, permissions and session locks. Provider-boundary tests use a controlled fake provider to exercise success, invalid credentials, recovery, OAuth, MFA and failures; they do not claim live Google consent, email delivery or a deployed Supabase end-to-end login. The actual Supabase SDK adapter is compiled and separately checked where possible. The final report records actual CI results.
