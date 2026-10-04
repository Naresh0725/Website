# PostgreSQL concurrency validation — PASS

Date: 4 October 2026
Repository: Naresh0725/Website
Branch: database-concurrency-validation
Tested commit: ad53c3b9d484ff67b1c30f305740716ee09611b0
CI run: https://github.com/Naresh0725/Website/actions/runs/37213643072
Job: https://github.com/Naresh0725/Website/actions/runs/37213643072/job/111469664488

## Observed results

Native PostgreSQL 17.11 on GitHub-hosted Ubuntu; Node 22.23.3; pg connection pool with up to 16 separate connections. Typecheck passed. Full suite: 30 passed, 0 failed, 0 skipped.

| Test | Observed assertion |
|---|---|
| Concurrent free starts | 12 distinct start requests: exactly 2 succeeded; other 10 rejected with SUBSCRIPTION_REQUIRED; used_count = 2 |
| Simultaneous retry requests | 12 requests sharing one idempotency key: one unique attempt and used_count = 1 |
| Start racing with restoration | Restoration succeeded; start either succeeded after restoration or was correctly denied; one audit entry; ledger total matched counter and stayed within limit |
| Concurrent payment fulfilment | 12 activations for one payment returned one subscription-period ID and stored one payment |
| Concurrent subscribed access and expiry | 12 subscribed starts created 12 distinct authorized attempts, keeping free_used = 2; all 12 subsequent starts after expiry were rejected |

No double-consumption or entitlement bypass was observed in these tested scenarios. This is concurrency/integration validation, not a production load test or live payment-provider end-to-end validation.

No database business-rule changes were needed for this run. The restoration race assertion was strengthened to require restoration success and reject unexpected start errors; two subscription-specific concurrency tests were added.

No UI was built or deployment performed. Changes remain on the test branch; main has only the initialization README. Await user approval before the next phase.
