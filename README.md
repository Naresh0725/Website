# Government Exam Platform — database foundation

Native PostgreSQL concurrency gate: **30 passed, 0 failed, 0 skipped**. See [validation report](docs/concurrency-validation.md).

Independent project, created 4 October 2026. No previous project or question bank is included.

## Implemented now

- PostgreSQL schema for identity, exams/syllabuses, versioned questions and PYQ evidence, tests, attempts, answers, results, analytics, billing, and administration.
- Atomic `start_attempt`, account provisioning, owner-scoped attempt lookup, and usage lookup.
- Exactly two free scored test starts per registered account across the platform. The first two charged starts are free even if a subscription was purchased early.
- Subsequent starts require applicable active subscription coverage.
- A subscription purchase grants exactly 720 elapsed hours (30 days). Renewal adds 720 hours after the current same-plan period, or from activation if expired.
- Free starts are charged in the same database transaction that creates their attempt and immutable question membership. Leaving, closing, logout, or refresh never reverses this charge.
- A retry of the same request returns the existing attempt. A genuinely new start uses a new request UUID and is charged normally.
- Privileged free-attempt restoration, requiring an authorized actor, explanation and incident reference. The attempt is voided, one charge is reversed, and append-only records preserve the audit trail.
- Separate database roles for runtime, identity, support and billing. They have function execution permissions, not direct table writes.
- Server-only authentication and payment-verification adapters; migration runner with checksums.
- Published question/test immutability, strict PYQ publication checks, and cross-attempt result integrity.

## Meaning of “when Start Test is clicked”

The future Start Test button must call the authenticated start endpoint immediately. A successful database commit consumes the attempt before its response returns or any test screen opens. The counter does not wait for an answer or submission. If the response is lost, retry with the same request UUID or resume the committed attempt.

A purely offline click cannot reach a server. An unauthenticated request, unpublished/invalid test, or failed database transaction creates no usable attempt and no charge. Once a start commits, closing the browser does not undo it.

## What is not built in this phase

No student/admin UI, deployed website, HTTP routes, complete CBT answer-saving/submission/scoring engine, dynamic blueprint generator, analytics worker, live checkout/webhook pipeline, refunds workflow, live Supabase project, or production database. These have schema support but are subsequent development phases. Blueprint attempts deliberately fail closed until generation is implemented. Fixed published fixtures exercise entitlement behavior now.

The server adapters need real infrastructure and verified session integration before deployment. Credentials are not included. A DB owner can always override a database: application/browser roles cannot. Never use the migration-owner connection for request handling.

## Run the checks

Node.js 22+ and npm:

```sh
npm ci
npm run typecheck
npm test
```

The default test run uses PGlite, an embedded PostgreSQL engine, without external services. It exercises SQL migrations, permissions, functions and triggers. It does NOT prove multi-connection locking. Five native PostgreSQL tests are explicitly skipped in this mode.

For a dedicated EMPTY PostgreSQL 17+ database:

```sh
TEST_DATABASE_URL=postgres://USER:PASSWORD@localhost:5432/EMPTY_TEST_DB ALLOW_EMPTY_TEST_DATABASE=yes npm test
```

The native run includes separate-connection contention tests. `.github/workflows/database.yml` defines this gate using PostgreSQL 17; the native run passed on 4 October 2026 (see validation report). Never point the tests at an existing application database.

PowerShell environment variables can be set with `$env:TEST_DATABASE_URL = "..."` and `$env:ALLOW_EMPTY_TEST_DATABASE = "yes"`, followed by `npm test`.

## Apply migrations to a new development database

```sh
DATABASE_URL=postgres://MIGRATION_OWNER:PASSWORD@HOST:5432/NEW_DATABASE npm run migrate
```

The migration login must be allowed to create schemas/roles/functions. The runner records hashes in `public.exam_migrations`, locks migration execution, and transactionally records each migration. Changed already-applied migrations are rejected. Production rollback is a reviewed forward migration or backup recovery, never a blanket schema drop.

After creating a NEW Supabase project and applying migrations, optionally run `db/deployment/supabase_identity.sql`. It links application identity to `auth.users` and provisions accounts on registration. It is intentionally outside generic migrations because generic PostgreSQL has no `auth.users` table.

Create server login credentials separately, using a secret manager, and grant each only its required role:

| Connection | Membership | Allowed functions |
|---|---|---|
| Runtime | `exam_runtime` | start, resume metadata, access status |
| Identity worker | `exam_identity` | idempotent user provisioning |
| Billing verifier | `exam_billing` | activate an independently verified captured payment |
| Support service | `exam_support` | restore; also checks actor's database permission |

Do not grant these roles to Supabase `anon`, `authenticated`, or any browser-accessible RPC. Keep `exam` outside exposed Data API schemas. All tables have RLS with no browser policies, and functions revoke PUBLIC execution. Use TLS for remote database connections.

## Key files

- `db/migrations/001_schema.sql`: entity definitions, constraints, basic catalogue seed.
- `db/migrations/002_access.sql`: atomic access, restoration, billing fulfilment, least-privilege roles.
- `db/migrations/003_integrity.sql`: question/test publication and immutability guards.
- `db/migrations/004_relationship_guards.sql`: result ownership and purchased-plan integrity.
- `src/access-service.ts`: verifies a Supabase access token server-side before using identity; requires verified email.
- `src/payment-verification.ts`: checks HMAC, independently retrieves captured payment, checks amount/currency/order, then activates access.
- `src/migrate.ts`: migration runner.
- `tests/database.test.ts`: actual database integration and optional multi-connection tests.
- `docs/architecture.md`: trust boundaries, transactions, remaining phases.
- `docs/schema.md`: generated table/relationship inventory.
- `docs/validation.md`: exact validation results and limitations.

## Production gate

The native PostgreSQL concurrency gate passed. Before launch, authentication must be integrated end-to-end, billing sandbox reconciliation/webhooks are tested, and the full CBT lifecycle is implemented and verified. No production readiness or live payment validation is claimed by this package.
