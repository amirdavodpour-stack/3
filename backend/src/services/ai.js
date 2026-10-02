const DEFAULT_ENDPOINT = 'http://localhost:20128/v1/chat/completions';
const DEFAULT_MODEL = 'apmix/deepseek-v4-flash-free';
const DEFAULT_TIMEOUT_MS = 45_000;

function providerError(status, code, message, cause) {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  if (cause) error.cause = cause;
  return error;
}

export function createAiService({
  fetchImpl = globalThis.fetch,
  env = process.env,
} = {}) {
  return {
    async askAI(question) {
      const endpoint = String(env.AI_ROUTER_URL || DEFAULT_ENDPOINT).trim();
      const apiKey = String(env.AI_ROUTER_API_KEY || '').trim();
      const model = String(env.AI_MODEL || DEFAULT_MODEL).trim();

      if (!apiKey) {
        throw providerError(503, 'AI_NOT_CONFIGURED', 'AI provider is not configured');
      }

      if (!endpoint || !model) {
        throw providerError(503, 'AI_NOT_CONFIGURED', 'AI provider configuration is invalid');
      }

      let response;
      try {
        response = await fetchImpl(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model,
            messages: [{ role: 'user', content: question }],
          }),
          signal: AbortSignal.timeout(Number(env.AI_TIMEOUT_MS || DEFAULT_TIMEOUT_MS)),
        });
      } catch (error) {
        throw providerError(502, 'AI_PROVIDER_UNAVAILABLE', 'AI provider is unavailable', error);
      }

      if (!response.ok) {
        throw providerError(502, 'AI_PROVIDER_ERROR', 'AI provider returned an error');
      }

      let payload;
      try {
        payload = await response.json();
      } catch (error) {
        throw providerError(502, 'AI_INVALID_RESPONSE', 'AI provider returned invalid JSON', error);
      }

      const answer = payload?.choices?.[0]?.message?.content;
      if (typeof answer !== 'string' || !answer.trim()) {
        throw providerError(502, 'AI_INVALID_RESPONSE', 'AI provider response did not contain an answer');
      }

      return answer;
    },
  };
}

export const { askAI } = createAiService();
