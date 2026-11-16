import crypto from 'node:crypto';

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const TOTP_STEP_SECONDS = 30;
const TOTP_DIGITS = 6;
const TOTP_WINDOW = 1;
const RECOVERY_CODE_BYTES = 16;

export function encodeBase32(input) {
  const bytes = Buffer.isBuffer(input) ? input : Buffer.from(input ?? []);
  let bits = 0;
  let value = 0;
  let output = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      output += BASE32_ALPHABET[(value >>> bits) & 31];
    }
    value &= (1 << bits) - 1;
  }
  if (bits > 0) output += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  return output;
}

export function decodeBase32(value) {
  const normalized = String(value ?? '')
    .toUpperCase()
    .replace(/[\s=-]/g, '');
  if (!normalized || /[^A-Z2-7]/.test(normalized)) {
    throw new TypeError('Invalid Base32 value');
  }
  let bits = 0;
  let buffer = 0;
  const output = [];
  for (const character of normalized) {
    buffer = (buffer << 5) | BASE32_ALPHABET.indexOf(character);
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      output.push((buffer >>> bits) & 0xff);
      buffer &= (1 << bits) - 1;
    }
  }
  // Base32 padding bits must be zero; reject non-canonical encodings.
  if (bits > 0 && buffer !== 0) throw new TypeError('Invalid Base32 padding bits');
  if (output.length === 0) throw new TypeError('Base32 value is empty');
  return Buffer.from(output);
}

export function generateTotpSecret() {
  return encodeBase32(crypto.randomBytes(20));
}

function validateTotpParameters({ stepSeconds, digits }) {
  if (!Number.isSafeInteger(stepSeconds) || stepSeconds < 15 || stepSeconds > 120) {
    throw new RangeError('TOTP stepSeconds must be an integer between 15 and 120');
  }
  if (!Number.isSafeInteger(digits) || digits < 6 || digits > 8) {
    throw new RangeError('TOTP digits must be an integer between 6 and 8');
  }
}

export function generateTotpCode(secret, atMs = Date.now(), options = {}) {
  const stepSeconds = options.stepSeconds ?? TOTP_STEP_SECONDS;
  const digits = options.digits ?? TOTP_DIGITS;
  validateTotpParameters({ stepSeconds, digits });
  if (!Number.isFinite(atMs) || atMs < 0) throw new RangeError('TOTP timestamp must be a non-negative finite number');
  const key = decodeBase32(secret);
  const counter = Math.floor(atMs / 1000 / stepSeconds);
  const message = Buffer.alloc(8);
  message.writeBigUInt64BE(BigInt(counter));
  const digest = crypto.createHmac('sha1', key).update(message).digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const binary =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);
  return String(binary % (10 ** digits)).padStart(digits, '0');
}

export function verifyTotpCode(secret, candidate, atMs = Date.now(), options = {}) {
  const stepSeconds = options.stepSeconds ?? TOTP_STEP_SECONDS;
  const digits = options.digits ?? TOTP_DIGITS;
  const window = options.window ?? TOTP_WINDOW;
  const lastAcceptedCounter = options.lastAcceptedCounter ?? -1;
  validateTotpParameters({ stepSeconds, digits });
  if (!Number.isSafeInteger(window) || window < 0 || window > 2) {
    throw new RangeError('TOTP window must be an integer between 0 and 2');
  }
  if (!Number.isFinite(atMs) || atMs < 0 || !Number.isSafeInteger(lastAcceptedCounter)) {
    return { valid: false, counter: null };
  }
  const supplied = String(candidate ?? '').trim();
  if (!new RegExp(`^[0-9]{${digits}}$`).test(supplied)) {
    return { valid: false, counter: null };
  }
  const nowCounter = Math.floor(atMs / 1000 / stepSeconds);
  const candidates = [];
  for (let offset = -window; offset <= window; offset += 1) {
    const counter = nowCounter + offset;
    if (counter > lastAcceptedCounter && counter >= 0) {
      candidates.push({ counter, distance: Math.abs(offset) });
    }
  }
  candidates.sort((a, b) => a.distance - b.distance);
  const suppliedBytes = Buffer.from(supplied, 'ascii');
  for (const item of candidates) {
    const expected = Buffer.from(
      generateTotpCode(secret, item.counter * stepSeconds * 1000, { stepSeconds, digits }),
      'ascii',
    );
    if (expected.length === suppliedBytes.length && crypto.timingSafeEqual(expected, suppliedBytes)) {
      return { valid: true, counter: item.counter };
    }
  }
  return { valid: false, counter: null };
}

function deriveEncryptionKey(masterKey) {
  if (typeof masterKey !== 'string' || Buffer.byteLength(masterKey, 'utf8') < 32) {
    throw new TypeError('Admin MFA encryption key must be at least 32 bytes');
  }
  return crypto.scryptSync(masterKey, 'hope-admin-mfa-encryption-v1', 32);
}

export function encryptTotpSecret(secret, masterKey) {
  // Validate the secret before encrypting it so malformed material cannot be stored.
  decodeBase32(secret);
  const key = deriveEncryptionKey(masterKey);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(String(secret).toUpperCase(), 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [
    'v1',
    iv.toString('base64url'),
    tag.toString('base64url'),
    ciphertext.toString('base64url'),
  ].join('.');
}

export function decryptTotpSecret(encrypted, masterKey) {
  const parts = String(encrypted ?? '').split('.');
  if (parts.length !== 4 || parts[0] !== 'v1') {
    throw new TypeError('Unsupported admin MFA ciphertext');
  }
  const [, ivText, tagText, ciphertextText] = parts;
  const iv = Buffer.from(ivText, 'base64url');
  const tag = Buffer.from(tagText, 'base64url');
  const ciphertext = Buffer.from(ciphertextText, 'base64url');
  if (iv.length !== 12 || tag.length !== 16 || ciphertext.length === 0) {
    throw new TypeError('Malformed admin MFA ciphertext');
  }
  const decipher = crypto.createDecipheriv('aes-256-gcm', deriveEncryptionKey(masterKey), iv);
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
  decodeBase32(plaintext);
  return plaintext;
}

export function hashRecoveryCode(code) {
  const normalized = String(code ?? '').trim().replace(/[-\s]/g, '').toUpperCase();
  if (!/^[A-F0-9]{32}$/.test(normalized)) {
    throw new TypeError('Invalid admin MFA recovery code');
  }
  return crypto.createHash('sha256').update(`hope-admin-recovery-v1:${normalized}`, 'utf8').digest('hex');
}

export function generateRecoveryCodes(count = 10) {
  if (!Number.isSafeInteger(count) || count < 1 || count > 20) {
    throw new RangeError('Recovery code count must be between 1 and 20');
  }
  const codes = Array.from({ length: count }, () => crypto.randomBytes(RECOVERY_CODE_BYTES).toString('hex').toUpperCase());
  return { codes, hashes: codes.map(hashRecoveryCode) };
}

export function buildTotpUri({ secret, email, issuer = 'HOPEv2' } = {}) {
  decodeBase32(secret);
  const account = String(email ?? '').trim().toLowerCase();
  const issuerName = String(issuer ?? '').trim();
  if (!account || !account.includes('@') || !issuerName) {
    throw new TypeError('A valid account email and issuer are required for TOTP setup');
  }
  const label = encodeURIComponent(`${issuerName}:${account}`);
  const query = new URLSearchParams({
    secret: String(secret).toUpperCase(),
    issuer: issuerName,
    algorithm: 'SHA1',
    digits: String(TOTP_DIGITS),
    period: String(TOTP_STEP_SECONDS),
  });
  return `otpauth://totp/${label}?${query.toString()}`;
}
