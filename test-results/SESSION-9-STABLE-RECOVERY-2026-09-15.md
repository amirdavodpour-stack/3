# HOPE / V2hope — Session 9 Stable Recovery Checkpoint

Date: 2026-09-15

## Executive result

The currently recovered executable source has been rebuilt to the latest available migration shape (001→021) and stabilized across financial, backend, architecture, mobile-boundary contracts, and legacy test adapters.

## Verified changes

- Financial Core amount semantics are currency-aware: TOMAN uses integer units with exact BigInt arithmetic and decimal-string boundaries; legacy currencies retain existing decimal/cents behavior.
- PostgreSQL→domain financial mappers and serialization preserve TOMAN amounts as strings rather than coercing them through JavaScript Number.
- Payment funding, refunds, webhooks, outbox, and reconciliation paths avoid TOMAN precision-loss coercions.
- Refund currency remains explicit via migration 021 and is carried through persistence/serialization.
- RELEASE semantics remain canonical: no second payer-side RELEASE debit after HOLD.
- Local payment webhook adapter now uses an injected database when provided rather than an unrelated singleton.
- Job report route fixed: handler now has the required id generator binding.
- Legacy admin application listing fixed: map callback now returns the application summary instead of producing undefined rows.
- Recruitment lifecycle contracts include the application use-case source of truth.
- Privacy repository port fixture is aligned with the actual capability slice.
- Notification device ownership contract targets repository-enforced ownership instead of a stale route-local implementation detail.
- TransactionsPage now reads through ApplicationRegistry/use-cases; Home premium responsive feed is composed through the home widget part.
- Migration checks run deterministically over migrations 001→021 with no duplicated command entries.
- Backend payment README explicitly documents production provider boundaries and internal TOMAN mode.

## Test evidence

- `npm run check:migrations` — PASS through 021
- Targeted financial/recovery suite — **26/26 PASS**
- Architecture/recruitment/privacy/notification/UX/Flutter-boundary batch — **22/22 PASS**
- Full `npm test` — **615/620 PASS, 0 FAIL, 5 SKIP**
- V2 design contract — **1/1 PASS**

## Runtime certification boundary

The five skipped tests require runtime infrastructure unavailable in this environment, including PostgreSQL/S3 integration. Full PostgreSQL multi-connection concurrency, production-like provider/reconciliation E2E, S3 lifecycle, Flutter/device certification, performance, DR, and production audit evidence are therefore still unverified.

## Source continuity note

The available source archives did not contain the exact Session 7 filesystem revision. Session 9 therefore rebuilt an executable recovery revision from the newest available source archive and reapplied the verified financial/migration hardening through migration 021. Session 7 claims must not be interpreted as byte-for-byte identity with this recovered tree.

## Safety boundary

No `main/production` source, branch, or production database was modified.

SHA-256 of this report: generated after final save.
