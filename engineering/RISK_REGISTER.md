# Risk Register — Execution Block 04

| Risk | Status | Impact | Required action |
|---|---|---|---|
| Runtime evidence gates unavailable in current environment | OPEN | High | Execute required CI/staging/device evidence |
| npm registry audit unavailable from current environment | OPEN | High | Run `npm audit --audit-level=high` in networked CI |
| PostgreSQL runtime certification pending | OPEN | Critical | Execute isolated PostgreSQL integration suite |
| Provider integration certification pending | OPEN | High | Execute staging provider integration |
| S3 lifecycle certification pending | OPEN | High | Execute real object-storage lifecycle |
| Flutter/Android/device certification pending | OPEN | High | Run Flutter analyze/test and Android/device certification |
| DR restore evidence pending | OPEN | High | Execute backup restore/chaos drill |
