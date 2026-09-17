# HOPE Release Checklist — v4.0.20

## Engineering baseline

- [ ] Node.js 24.x is used in CI and release automation.
- [ ] Backend static checks and contract tests pass on the release SHA.
- [ ] Flutter dependency lock is fresh and `flutter test --no-pub` passes on the release SHA.
- [ ] Release workflows use immutable GitHub Action references.
- [ ] Runtime evidence is emitted from observed gate outcomes.

## Staging certification

- [ ] Real staging base URL is configured over HTTPS.
- [ ] PostgreSQL runtime gate is executed and evidence is attached.
- [ ] S3 runtime gate is executed against the staging endpoint and evidence is attached.
- [ ] Payment/provider runtime gate is executed with its required external integration.
- [ ] Performance smoke executes the configured 500-request/50-concurrency budget.
- [ ] Disaster-recovery restore drill completes and emits evidence.
- [ ] Android emulator certification completes on the release SHA.

## Production candidate

- [ ] Staging certification status is PASS and its run id, SHA, and attempt are bound to the production release SHA.
- [ ] Production environment validation uses only production secrets.
- [ ] `npm run check:all` passes.
- [ ] Flutter static analysis and tests pass.
- [ ] `ANDROID_RELEASE_KEYSTORE_B64` is supplied through the protected production environment.
- [ ] Signed APK verification uses `apksigner verify --verbose`.
- [ ] SBOM, SHA256SUMS, release manifest, and build provenance are generated.
- [ ] Production keystore material is removed after the build, even on failure.

## Post-release / future gates

- [ ] Real PSP adapter and sandbox verification completed before enabling live external payments.
- [ ] Physical Android device QA completed before store submission.
- [ ] Operational monitoring and alert delivery are verified in the deployed environment.
