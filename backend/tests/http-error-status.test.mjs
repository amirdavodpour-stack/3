import test from 'node:test';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
const { sendError } = await import('../src/http.js');

function mockResponse() {
  const headers = new Map();
  return {
    statusCode: 200,
    setHeader(name, value) { headers.set(name, value); },
    getHeader(name) { return headers.get(name); },
    writeHead(status) { this.statusCode = status; },
    end(body) { this.body = body; },
  };
}

test('sendError preserves intentional status and code on generic application errors', () => {
  const res = mockResponse();
  const error = new Error('PRIMARY_ADMIN_ONLY');
  error.status = 403;
  error.code = 'PRIMARY_ADMIN_ONLY';
  sendError(res, error);
  assert.equal(res.statusCode, 403);
  assert.equal(JSON.parse(res.body).error.code, 'PRIMARY_ADMIN_ONLY');
});
