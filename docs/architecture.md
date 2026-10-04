# Architecture and approved policy

## Boundaries

Future browser → authenticated server API → domain functions → PostgreSQL. Authentication is managed by a new Supabase project; its UUID is the stable application identity. No browser ID is trusted. `AccessService` obtains the identity from the auth server instead of decoding an unverified JWT or accepting a user ID from input.

The application is a modular monolith with a separate eventual worker. PostgreSQL stores authoritative entitlement and timing. Supabase Storage can hold source documents and question media privately. Next.js and UI styling remain planned, not installed. Reviewed SQL is authoritative at this phase; `pg` invokes database transactions/functions directly. Drizzle mappings may be added later without weakening SQL constraints.

## Modules and responsibilities

| Module | Responsibility |
|---|---|
| Identity | Managed login, account lifecycle, profiles and RBAC |
| Catalogue | Exam family → exam → stage → syllabus version → subject → topic |
| Questions | Original/generated origin, immutable versions, translations, keys, evidence, reviews |
| Tests | Fixed papers and future blueprints, sections and rules |
| Attempts | Start authorization, exact membership and timer snapshots; future answer/submission lifecycle |
| Entitlements | Two free starts and active paid access |
| Billing | Price snapshots, verified payments and 30-day periods |
| Analytics | Rebuildable summaries from immutable scored results |
| Administration | Permissions and auditable exceptional actions |
| Worker | Event outbox, future expiry/scoring/analytics/reconciliation jobs |

## Approved rules

1. Starts 1 and 2 are FREE across all scored mock modes and all exams, per account.
2. Start 3 and later require subscription access, except an explicitly restored free charge.
3. Every new scored test sitting is a separate persisted attempt, including subscription sittings.
4. Charging occurs on accepted Start Test, not completion.
5. Browser exit, inactivity, logout, refresh and abandonment never refund a charge.
6. Confirmed platform incidents can restore a free charge once, with an authorized actor and audit trail.
7. Paid intervals are exactly 30 days (720 hours), using server time and `[starts_at, ends_at)` boundaries.
8. Neither localStorage nor client counters authorize access.

The latest exact first-two-FREE rule supersedes the earlier proposal to preserve free starts when already subscribed. Restorations are explicit exceptions: the historical attempt stays recorded, its status becomes voided, and the replacement consumes the recovered credit. Paid access is unlimited within its coverage interval, so a paid attempt cannot be converted into an extra free credit. No automatic extension of paid time is assumed.

## Start transaction

`start_attempt` locks the account's allowance row using FOR UPDATE. All starting, restoration and payment-activation operations serialize on this row. It then checks replay keys, validates the published fixed test, verifies entitlement using server time, creates the attempt and exact question/option ordering, records authorization, and debits a free start when applicable. Failure rolls back every step. Database constraints disallow a negative balance or more than two unreversed free charges.

A duplicate key on the same user returns the same attempt even after later expiry, because it is a replay, not another start. Changing the requested test while reusing a key is rejected. A voided attempt is never reopened by replaying its key. Retrying with a new key represents a genuinely new start and may spend a second free attempt; the future client must retain its request key through uncertain responses.

The user identity survives every login and device. Concurrent requests cannot obtain separate allowances. New-account fraud is different from session bypass: the approved rule is per registered account, not identity-proofed human.

## Timer and subscriptions

Attempt deadlines are frozen at start and do not depend on the browser clock. Subscription validity is checked for new starts. Expiry during an already-authorized sitting does not revoke that sitting's original deadline. Resume metadata never charges again and reports whether the deadline has passed. Submission/expiry enforcement belongs to the next CBT engine phase; metadata lookup is not an answer-writing endpoint.

One captured verified purchase creates one 720-hour period. A repeated payment or webhook cannot create another period. Same-plan renewals append from the existing active period's end; expired coverage restarts at activation. Plans have immutable versions and fixed 30-day duration. Production plan prices are intentionally not seeded. The 99-rupee value in tests is synthetic fixture data only.

## Restoration

Only a support backend with `exam_support` can call `restore_attempt`. The function additionally resolves the supplied authenticated actor's `attempt.restore` permission and active account. Incident reference, explanation and request ID are mandatory. It voids the affected free attempt, reverses its original ledger event, lowers used_count once, writes an immutable audit record, and emits an analytics invalidation event. Repeated restoration returns the previous restoration ID. The incident's authenticity is a human/service operational judgment; SQL cannot determine whether an outage truly happened.

System automation must use a dedicated accountable service identity with the same permission, not an anonymous actor. Paid attempts cannot mint free credits. Later support UI may expose paid-incident investigation separately.

## Payment verification boundary

Only the billing credential may call activation. SQL cannot independently check a payment provider signature; this is the trusted server adapter's responsibility. It verifies checkout HMAC, fetches the payment from the provider, checks captured status/order/amount/currency, and supplies a SHA-256 evidence hash. SQL independently checks stored order/plan pricing and idempotency.

Actual order creation, authenticated purchase endpoints, durable raw-body webhook handling, retries, refunds and disputes are not exposed in this phase. Tables exist for them. A production webhook pipeline must authenticate the raw body, deduplicate event IDs, tolerate unordered delivery and reconcile against provider APIs. A valid signature alone is insufficient to activate a payment that is only authorized, not captured.

Official references: https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/integration-steps/ and https://razorpay.com/docs/webhooks/validate-test/ .

## Question provenance and immutable records

Question origin is original, generated or historical. Paper occurrence evidence is independently unverified, paper_verified or verified_pyq. Strict PYQ test publication requires a verified occurrence for the same exam stage. Verified PYQ occurrence requires historical origin, paper evidence and final official key evidence. Generated questions cannot pass that gate.

Published question content, options, answer key, mappings and linked group content cannot be edited. Published test rules and members are immutable. Corrections create a new version. Imports and content verification workflows will be implemented before authoring permissions are granted; schema flags are not themselves human evidence. No questions from previous projects are used.

## Security and deployment

Migration ownership and runtime credentials are separate. Runtime cannot SELECT answer keys or UPDATE attempt/allowance/subscription rows. Browser roles have no schema grants. All SECURITY DEFINER access functions set a restricted search path and do not execute dynamic user SQL. RLS is enabled for defense in depth. A database owner necessarily retains administration rights and must not serve web requests.

No real account, payment, token or secret appears in logs/fixtures. Production must add CSRF protection to cookie-authenticated routes, rate limiting, admin MFA, secure cookies, secret management, private storage URLs, upload/content sanitization, source rights review, monitoring and restore-tested backups. None is claimed to exist merely because it is described here.

## Remaining phases

1. Run native PostgreSQL CI gate and provision separate development infrastructure.
2. Connect managed authentication and actual server routes; verify identity/session isolation end to end.
3. Implement content review/import/admin services and exam-specific publication validation.
4. Implement full answer saving, server expiry, submission/scoring, and dynamic blueprints with dedicated tests.
5. Integrate gateway sandbox orders, checkout, webhook inbox and reconciliation; test refunds/disputes policy.
6. Build student and admin interfaces only in their authorized phase.
7. Add analytics/weak-topic generation and launch readiness checks.

Descriptive UPSC papers, interviews, typing and physical assessments need separate later modules.
