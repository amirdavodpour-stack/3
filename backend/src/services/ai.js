const DEFAULT_ROUTER_URL = 'http://localhost:20128/v1';
const DEFAULT_MODEL = 'apmix/deepseek-v4-flash-free';
const DEFAULT_TIMEOUT_MS = 30000;

function envString(name, fallback = '') {
  const value = process.env[name];
  return value == null || value === '' ? fallback : String(value);
}

export function resolveAiEndpoint(routerUrl = envString('AI_ROUTER_URL', DEFAULT_ROUTER_URL)) {
  const base = String(routerUrl).trim().replace(/\/+$/, '');
  return /\/chat\/completions$/.test(base) ? base : base + '/chat/completions';
}

export function createAiService({ fetchImpl = globalThis.fetch, env = process.env } = {}) {
  if (typeof fetchImpl !== 'function') throw new Error('Fetch implementation is unavailable');

  return async function askAI(message) {
    const text = typeof message === 'string' ? message.trim() : '';
    if (!text) throw Object.assign(new Error('Message is required'), { code: 'INVALID_MESSAGE', status: 400 });
    if (text.length > 12000) throw Object.assign(new Error('Message is too long'), { code: 'MESSAGE_TOO_LONG', status: 400 });

    const apiKey = String(env.AI_ROUTER_API_KEY || '').trim();
    if (!apiKey) throw Object.assign(new Error('AI router is not configured'), { code: 'AI_NOT_CONFIGURED', status: 503 });

    const controller = new AbortController();
    const timeoutValue = Number(env.AI_TIMEOUT_MS || DEFAULT_TIMEOUT_MS);
    const timeoutMs = Number.isFinite(timeoutValue) && timeoutValue > 0 ? timeoutValue : DEFAULT_TIMEOUT_MS;
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    timer.unref?.();

    try {
      const response = await fetchImpl(resolveAiEndpoint(String(env.AI_ROUTER_URL || DEFAULT_ROUTER_URL)), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + apiKey,
        },
        body: JSON.stringify({
          model: String(env.AI_MODEL || DEFAULT_MODEL).trim(),
          messages: [{ role: 'user', content: text }],
          stream: false,
        }),
        signal: controller.signal,
      });

      const raw = await response.text();
      let payload;
      try {
        payload = raw ? JSON.parse(raw) : {};
      } catch (error) {
        const invalid = new Error('AI provider returned invalid JSON');
        invalid.code = 'AI_INVALID_RESPONSE';
        invalid.status = 502;
        invalid.cause = error;
        throw invalid;
      }

      if (!response.ok) {
        const error = new Error('AI provider request failed');
        error.code = 'AI_PROVIDER_ERROR';
        error.status = 502;
        error.providerStatus = response.status;
        throw error;
      }

      const answer = payload?.choices?.[0]?.message?.content;
      if (typeof answer !== 'string' || !answer.trim()) {
        const error = new Error('AI provider returned an invalid response');
        error.code = 'AI_INVALID_RESPONSE';
        error.status = 502;
        throw error;
      }

      return answer.trim();
    } catch (error) {
      if (error?.name === 'AbortError') {
        const timeout = new Error('AI provider request timed out');
        timeout.code = 'AI_TIMEOUT';
        timeout.status = 504;
        throw timeout;
      }
      if (error?.code?.startsWith?.('AI_')) throw error;
      const unavailable = new Error('AI provider is unavailable');
      unavailable.code = 'AI_PROVIDER_UNAVAILABLE';
      unavailable.status = 502;
      unavailable.cause = error;
      throw unavailable;
    } finally {
      clearTimeout(timer);
    }
  };
}

export const askAI = createAiService();
