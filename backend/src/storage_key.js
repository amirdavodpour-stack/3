const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SAFE_SEGMENT = /^[a-zA-Z0-9._-]{1,180}$/;

export function createUploadObjectKey({ storageBackend = 'local', prefix = '', fileId, safeName } = {}) {
  if (
    !UUID_V4.test(String(fileId || ''))
    || typeof safeName !== 'string'
    || !SAFE_SEGMENT.test(safeName)
    || safeName === '.'
    || safeName === '..'
  ) {
    throw new Error('STORAGE_KEY_INVALID');
  }
  const filename = `${fileId}-${safeName}`;
  if (storageBackend !== 's3') return filename;

  if (typeof prefix !== 'string' || prefix.length < 1 || prefix.length > 128) throw new Error('STORAGE_KEY_INVALID');
  const segments = prefix.split('/');
  if (segments.some((segment) => !SAFE_SEGMENT.test(segment) || segment === '.' || segment === '..')) {
    throw new Error('STORAGE_KEY_INVALID');
  }
  return `${segments.join('/')}/${filename}`;
}
