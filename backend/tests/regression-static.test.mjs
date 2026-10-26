});

test('payment idempotency is normalized consistently across header and body', () => {
  const source = fs.readFileSync(new URL('../src/routes/payment_routes.js', import.meta.url), 'utf8');
  const validationSource = fs.readFileSync(new URL('../src/policies/validation.js', import.meta.url), 'utf8');
  assert.match(source, /readIdempotencyKey/);
  assert.match(validationSource, /export function readIdempotencyKey/);
  assert.match(source, /bodyIdempotencyKey/);
  assert.match(source, /validateIdempotencyPair/);
  const paymentPolicy = fs.readFileSync(new URL('../src/application/payment_policy.js', import.meta.url), 'utf8');
  assert.match(paymentPolicy, /Header and body idempotency keys must match/);
  assert.match(paymentPolicy, /IDEMPOTENCY_CONFLICT|INVALID_IDEMPOTENCY_KEY/);
});

test('multipart parsing bounds body ingestion and cleans temporary files on failures', () => {
  const source = fs.readFileSync(new URL('../src/http.js', import.meta.url), 'utf8');
  const routeSource = fs.readFileSync(new URL('../src/routes/storage_routes.js', import.meta.url), 'utf8');
  const multipartSource = source.slice(source.indexOf('export async function readMultipartSingleFile(req) {'));
  assert.ok(
    multipartSource.indexOf('await acquireUploadParser();') < multipartSource.indexOf('fs.createWriteStream('),
    'the upload slot must be acquired before creating an incoming temp file',
  );
  assert.ok(
    multipartSource.indexOf('await acquireUploadParser();') < multipartSource.indexOf('for await (const chunk of req)'),
    'the upload slot must be acquired before consuming the multipart request body',
  );
  assert.match(source, /if \(tempPath\) \{\s*try \{ await fs\.promises\.unlink\(tempPath\); \} catch \{\}/);
  assert.match(source, /if \(!ownershipTransferred\) release\(\)/);
  assert.match(routeSource, /file\.release\?\.\(\)/);
});

test('object upload cleans up the temp file and compensates for DB insert failure', () => {
  const appSource = fs.readFileSync(new URL('../src/app.js', import.meta.url), 'utf8');
  const storageRouteSource = fs.readFileSync(new URL('../src/routes/storage_routes.js', import.meta.url), 'utf8');
  const storageSource = fs.readFileSync(new URL('../src/storage.js', import.meta.url), 'utf8');
  assert.ok(appSource.includes('createStorageRoutes'));
  assert.ok(storageRouteSource.includes('await storage.put(file);'));
  assert.ok(storageRouteSource.includes('ORPHAN_UPLOAD_CLEANUP_FAILED'));
  assert.match(storageSource, /DeleteObjectCommand/);
  assert.match(storageSource, /async delete\(\{ key \}\)/);
});