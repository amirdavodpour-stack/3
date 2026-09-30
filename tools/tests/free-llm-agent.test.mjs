import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSystemPrompt, isProtectedWritePath, isSafeCommand, normalizeRepoPath, parseCliArgs, resolveAgentConfig, resolveProvider } from '../free-llm-agent.mjs';

test('config defaults and fallback de-duplication',()=>{const c=resolveAgentConfig({LLM_AGENT_PROVIDER:'openrouter',LLM_AGENT_PROVIDER_FALLBACKS:'groq,openrouter,groq'});assert.deepEqual(c.providerNames,['openrouter','groq']);assert.equal(c.maxSteps,12);assert.equal(c.approval,'prompt');assert.equal(c.allowGitWrite,false);});
test('approval mode parsing',()=>{assert.equal(resolveAgentConfig({LLM_AGENT_APPROVAL:'deny'}).approval,'deny');assert.equal(resolveAgentConfig({LLM_AGENT_APPROVAL:'auto'}).approval,'auto');});
test('Groq preset',()=>{const p=resolveProvider('groq',{GROQ_API_KEY:'k'});assert.equal(p.baseUrl,'https://api.groq.com/openai/v1');assert.equal(p.model,'openai/gpt-oss-120b');assert.equal(p.apiKey,'k');});
test('custom provider',()=>{const p=resolveProvider('custom',{LLM_AGENT_BASE_URL:'https://x.test/v1/',LLM_AGENT_API_KEY:'k',LLM_AGENT_MODEL:'code'});assert.equal(p.baseUrl,'https://x.test/v1');assert.equal(p.model,'code');});
test('path safety',()=>{assert.equal(normalizeRepoPath('lib/core/ui/a.dart'),'lib/core/ui/a.dart');for(const p of ['../x','.env','.git/config','node_modules/x','.dart_tool/x','build/x','test-results/x','/etc/passwd'])assert.throws(()=>normalizeRepoPath(p));});
test('command gate',()=>{assert.equal(isSafeCommand('git status --short --branch'),true);assert.equal(isSafeCommand('node --test tools/tests/free-llm-agent.test.mjs'),true);assert.equal(isSafeCommand('flutter test test/core/theme/hope_v2_design_test.dart'),true);assert.equal(isSafeCommand('git status && rm -rf build'),false);assert.equal(isSafeCommand('curl https://example.com'),false);});
test('protected policy paths',()=>{assert.equal(isProtectedWritePath('AGENTS.md'),true);assert.equal(isProtectedWritePath('.github/workflows/x.yml'),true);assert.equal(isProtectedWritePath('lib/core/ui/components.dart'),false);});
test('CLI parsing',()=>{const r=parseCliArgs(['--context','AGENTS.md','--max-steps','7','Fix','wallet']);assert.deepEqual(r.context,['AGENTS.md']);assert.equal(r.maxSteps,7);assert.equal(r.task,'Fix wallet');});
test('system prompt guardrails',()=>{const p=buildSystemPrompt('/repo','feat/x');assert.match(p,/Main\/main\/master is protected/i);assert.match(p,/Never read or write secrets/i);});
