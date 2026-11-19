const ALLOWED_UPLOAD_TYPES = new Set([
  'application/pdf', 'image/png', 'image/jpeg', 'image/webp',
  'text/plain', 'audio/mp4', 'audio/mpeg', 'audio/wav',
]);

export async function createSupabaseSignedUpload({
  endpoint,
  bucket,
  key,
  contentType,
  serviceKey,
  expiresIn = 300,
  fetchImpl = fetch,
} = {}) {
  let s3Url;
  try { s3Url = new URL(String(endpoint || '')); } catch { throw new Error('SUPABASE_SIGNED_UPLOAD_CONFIG_INVALID'); }
  const keySegments = typeof key === 'string' ? key.split('/') : [];
  if (
    s3Url.protocol !== 'https:'
    || !s3Url.hostname.toLowerCase().endsWith('.storage.supabase.co')
    || s3Url.username
    || s3Url.password
    || s3Url.search
    || s3Url.hash
    || s3Url.pathname.replace(/\/+$/, '') !== '/storage/v1/s3'
    || bucket !== 'v2hope-private'
    || keySegments.length < 2
    || keySegments.some((segment) => !segment || segment === '.' || segment === '..' || !/^[a-zA-Z0-9._-]+$/.test(segment))
    || !ALLOWED_UPLOAD_TYPES.has(contentType)
    || typeof serviceKey !== 'string'
    || Buffer.byteLength(serviceKey, 'utf8') < 32
    || typeof fetchImpl !== 'function'
    || !Number.isSafeInteger(expiresIn)
    || expiresIn < 30
    || expiresIn > 86400
  ) {
    throw new Error('SUPABASE_SIGNED_UPLOAD_CONFIG_INVALID');
  }

  const apiBasePath = s3Url.pathname.replace(/\/+$/, '').replace(/\/s3$/, '');
  const apiBase = new URL(apiBasePath, s3Url.origin);
  const encodedKey = keySegments.map((segment) => encodeURIComponent(segment)).join('/');
  const signedPath = apiBase.pathname + '/object/upload/sign/' + encodeURIComponent(bucket) + '/' + encodedKey;
  const signEndpoint = apiBase.origin + signedPath;
  let response;
  try {
    response = await fetchImpl(signEndpoint, {
      method: 'POST',
      redirect: 'manual',
      signal: AbortSignal.timeout(10000),
      headers: {
        apikey: serviceKey,
        authorization: 'Bearer ' + serviceKey,
        'content-type': 'application/json',
      },
      body: JSON.stringify({}),
    });
  } catch {
    throw new Error('SUPABASE_SIGNED_UPLOAD_FAILED');
  }
  if (!response || !response.ok || response.status < 200 || response.status >= 300) {
    throw new Error('SUPABASE_SIGNED_UPLOAD_FAILED');
  }

  let payload;
  try { payload = await response.json(); } catch { throw new Error('SUPABASE_SIGNED_UPLOAD_INVALID_RESPONSE'); }
  if (typeof payload?.url !== 'string' || !payload.url) {
    throw new Error('SUPABASE_SIGNED_UPLOAD_INVALID_RESPONSE');
  }

  let signedUrl;
  try {
    const rawUrl = payload.url.startsWith('https://')
      ? payload.url
      : apiBase.origin + apiBase.pathname + (payload.url.startsWith('/') ? payload.url : '/' + payload.url);
    signedUrl = new URL(rawUrl);
  } catch {
    throw new Error('SUPABASE_SIGNED_UPLOAD_INVALID_RESPONSE');
  }
  if (
    signedUrl.origin !== apiBase.origin
    || signedUrl.pathname !== signedPath
    || signedUrl.username
    || signedUrl.password
    || signedUrl.hash
    || signedUrl.searchParams.getAll('token').length !== 1
    || !signedUrl.searchParams.get('token')
  ) {
    throw new Error('SUPABASE_SIGNED_UPLOAD_INVALID_RESPONSE');
  }

  return {
    key,
    url: signedUrl.toString(),
    contentType,
    mode: 'supabase-signed',
    expiresIn: 7200,
    intentExpiresIn: expiresIn,
    requiredHeaders: { 'x-upsert': 'false', 'Content-Type': contentType },
  };
}
