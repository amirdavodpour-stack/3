import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(new URL('../../', import.meta.url).pathname);
const workflow = fs.readFileSync(path.join(root, '.github/workflows/device-integration.yml'), 'utf8');
const production = fs.readFileSync(path.join(root, '.github/workflows/production-release.yml'), 'utf8');
const staging = fs.readFileSync(path.join(root, '.github/workflows/staging-certification.yml'), 'utf8');
const smoke = fs.readFileSync(path.join(root, 'integration_test/runtime/app_smoke_test.dart'), 'utf8');

test('device certification workflow uses a pinned emulator runner and HTTPS staging', () => {
  assert.match(workflow, /reactivecircus\/android-emulator-runner@[0-9a-f]{40} # v2\.38\.0/);
  assert.match(workflow, /subosito\/flutter-action@[0-9a-f]{40} # v2\.23\.0/);
  assert.match(workflow, /actions\/checkout@[0-9a-f]{40} # v6\.0\.2/);
  assert.match(workflow, /api-level: 35/);
  assert.match(workflow, /API_BASE_URL_STAGING/);
  assert.match(workflow, /https:\/\//);
  assert.match(workflow, /CI_DEVICE_INTEGRATION=true/);
});

test('device emulator runner script remains POSIX-sh compatible', () => {
  assert.doesNotMatch(workflow, /script:\s*\|\s*\n\s*set\s+[^\n]*pipefail/);
  assert.match(workflow, /script:\s*\|[\s\S]*?flutter test --no-pub integration_test\/runtime\/app_smoke_test\.dart/);
  assert.match(workflow, /bash tools\/android-staging-network-preflight\.sh/);
});

test('staging certification performs device certification before any production signing job can run', () => {
  const deviceIndex = staging.indexOf('Android emulator certification');
  assert.ok(deviceIndex >= 0);
  assert.match(production, /needs: staging-certification/);
  assert.doesNotMatch(production, /API_BASE_URL_STAGING/);
  assert.match(staging, /subosito\/flutter-action@[0-9a-f]{40} # v2\.23\.0/);
  assert.match(staging, /reactivecircus\/android-emulator-runner@[0-9a-f]{40} # v2\.38\.0/);
  assert.match(staging, /certification_sha/);
  assert.match(staging, /certification_attempt/);
});

test('integration smoke derives the API endpoint from build-time configuration', () => {
  assert.match(smoke, /String\.fromEnvironment\('API_BASE_URL'/);
  assert.match(smoke, /CI_DEVICE_INTEGRATION/);
  assert.match(smoke, /\$baseUrl\/live/);
});

test('Android Gradle workflows pin Temurin JDK 17 before Flutter and emulator builds', () => {
  const workflows = [
    'hope-ui-wave-1-static.yml',
    'hope-ui-runtime-evidence.yml',
    'android-emulator-certification.yml',
    'device-integration.yml',
    'staging-certification.yml',
    'release-validation.yml',
    'production-release.yml',
    'one-shot-current-head-validation.yml',
    'hope-home-visual-preview.yml',
    'hope-maestro-first-real.yml',
  ];
  for (const name of workflows) {
    const body = fs.readFileSync(path.join(root, '.github/workflows', name), 'utf8');
    const javaIndex = body.indexOf('      - name: Setup Java 17');
    const flutterIndex = body.indexOf('      - name: Setup Flutter 3.47.2');
    assert.ok(javaIndex >= 0, name + ' must pin JDK 17 before invoking Gradle');
    assert.ok(flutterIndex > javaIndex, name + ' must select JDK 17 before Flutter captures its Java toolchain');
    const javaStep = body.slice(javaIndex, flutterIndex);
    assert.ok(javaStep.includes('uses: actions/setup-java@b843ebf9b913146b38da2eaa7aeddf76074ae1ad # v6.1.0'));
    assert.ok(javaStep.includes('distribution: temurin'));
    assert.ok(javaStep.includes('java-version: "17"'));
  }
});
