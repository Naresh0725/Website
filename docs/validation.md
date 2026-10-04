# Validation report — 4 October 2026

## Results actually observed

- TypeScript strict typecheck: PASS.
- Four migrations applied to a new embedded PostgreSQL (PGlite) database: PASS.
- SQL integration/security tests: 25 PASS, 0 FAIL.
- Native PostgreSQL multi-connection tests: 3 SKIPPED locally; not claimed as verified.
- 65 domain tables present, all with row-level security enabled.

Tests cover two immediate free starts, third-start rejection, replay idempotency, request mismatch, login/provisioning persistence, abandoned attempts, invalid-start rollback, account ownership, suspension, DB-role isolation, audited restoration, restoration replay, incident requirements, immutable ledgers, verified payment activation, exact 720-hour duration, duplicate payment fulfilment, amount mismatch, expiration, future/revoked coverage, exam coverage, paid attempts not creating free credits, published content immutability and HMAC validation.

The TypeScript adapters compile. No actual Supabase or Razorpay account was contacted to validate live sessions or payments. Gateway HMAC correctness is tested with synthetic inputs; end-to-end gateway verification is a later sandbox gate.

## Concurrency limitation and required gate

The local environment has no installed standalone PostgreSQL server and does not permit starting the required separate unprivileged database process. PGlite is suitable for actual PostgreSQL SQL semantics here, but its single embedded connection is not evidence for contention between independent production connections.

The included native tests use a pg connection pool and concurrent starts. They verify:

1. Twelve simultaneous distinct starts yield exactly two free attempts.
2. Twelve simultaneous retries of one request yield one attempt and one charge.
3. Restoration racing with a start leaves the ledger and counter consistent.

`.github/workflows/database.yml` runs these tests against a PostgreSQL 17 service. This workflow is supplied but has not been executed on GitHub. Passing the native gate is required before deployment.

## Delivery scope

Source files, SQL migrations, documentation and tests only. No UI, external deployment, live database mutation, production plan pricing or previous project data.
