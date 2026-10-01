# HOPE Free LLM Coding Agent

This repository now includes a dependency-free Node.js coding agent that can use OpenAI-compatible LLM APIs, inspect the live checkout, modify source files, run focused verification, and — only when explicitly authorized — commit, push, and open a pull request.

The implementation is intentionally provider-agnostic. The current `awesome-free-llm-apis` catalog lists OpenRouter, Groq, and GitHub Models among the free-tier inference options, and its setup guide shows the OpenAI SDK compatibility pattern. Provider availability and free-tier limits can change, so keep the model/provider in environment variables instead of baking credentials into the repository.

## 1. Install nothing

The agent uses Node's built-in `fetch`, filesystem, process, and readline APIs. The repository already targets Node 24 for the backend toolchain.

Check:

```bash
node --version
```

## 2. Choose a free provider

### OpenRouter

The current catalog lists free models with the `:free` suffix. A code-oriented example currently listed is:

```bash
export LLM_AGENT_PROVIDER=openrouter
export LLM_AGENT_MODEL=cohere/north-mini-code:free
export OPENROUTER_API_KEY='YOUR_KEY'
```

Endpoint:

```text
https://openrouter.ai/api/v1
```

### Groq

Groq documents an OpenAI-compatible endpoint:

```bash
export LLM_AGENT_PROVIDER=groq
export LLM_AGENT_MODEL=openai/gpt-oss-120b
export GROQ_API_KEY='YOUR_KEY'
```

Endpoint:

```text
https://api.groq.com/openai/v1
```

### GitHub Models

The catalog also documents GitHub Models as an OpenAI-compatible inference provider. Use the token and endpoint from the current GitHub Models documentation/account configuration:

```bash
export LLM_AGENT_PROVIDER=github-models
export GITHUB_TOKEN='YOUR_TOKEN'
```

The default model in the repository agent is `gpt-4o`; override it with `LLM_AGENT_MODEL` when the available model set differs.

### Custom OpenAI-compatible provider

```bash
export LLM_AGENT_PROVIDER=custom
export LLM_AGENT_BASE_URL='https://your-provider.example/v1'
export LLM_AGENT_MODEL='your-model'
export LLM_AGENT_API_KEY='YOUR_KEY'
```

## 3. Run the agent from GitHub Actions (no Termux or Codespaces)

The repository also includes a manual GitHub Actions runner for this agent. It uses the same coding loop against the active branch and the OpenRouter Free Models Router by default.

1. In the repository, open **Settings -> Secrets and variables -> Actions**.
2. Create a repository secret named `OPENROUTER_API_KEY` and paste the OpenRouter key there.
3. Open **Actions -> HOPE Free LLM Coding Agent -> Run workflow** on the feature branch.
4. Enter the task in the `task` field. The default model is `openrouter/free`.
5. Leave `allow_git_write` off for a dry/review pass. Turn it on only when you explicitly want the agent to be allowed to commit, push, or create a PR.
6. Download `agent-output.txt` and `agent-diff.patch` from the run artifacts when reviewing a non-persisted pass.

The workflow is manual-only so a pull request or push does not automatically send repository contents to the external inference provider. The OpenRouter key is supplied only to the agent step through the GitHub Actions secrets context.

## 3. Run the agent in safe interactive mode

Default approval mode is `prompt`.

```bash
node tools/free-llm-agent.mjs \
  --context AGENTS.md \
  --context V2-DESIGN-SYSTEM-SPEC.md \
  "Inspect the current visual system and implement the smallest coherent improvement that moves the Flutter UI toward the canonical premium direction. Run a focused test afterward."
```

The model can call repository tools for:

- Git status, diff, tracked-file listing, file reads, and code search.
- Unified-diff application and complete-file writes.
- Focused test/check commands.
- Commit, push, and PR creation only behind explicit authorization.

The agent automatically receives the branch name and the core HOPE repository guardrails in its system prompt.

## 4. Enable provider fallback

You can keep a secondary free provider ready for transient 429/5xx failures:

```bash
export LLM_AGENT_PROVIDER=openrouter
export LLM_AGENT_PROVIDER_FALLBACKS=groq
```

The agent resolves the correct provider-specific API key from:

```text
OPENROUTER_API_KEY
GROQ_API_KEY
GITHUB_TOKEN
```

or from the generic `LLM_AGENT_API_KEY`.

## 5. Git write authorization

The agent never pushes or creates a PR merely because a model asked to do it.

To allow Git write operations:

```bash
export LLM_AGENT_ALLOW_GIT_WRITE=1
export LLM_AGENT_APPROVAL=prompt
```

The agent still asks before each commit, push, or PR.

`Main`/`main` is always rejected as a write target.

For unattended execution, `LLM_AGENT_APPROVAL=auto` is available, but Git writes remain disabled until `LLM_AGENT_ALLOW_GIT_WRITE=1`. Auto mode also refuses shell commands outside the built-in command allowlist.

## 6. What this is — and is not

This is a local, Claude-Code/Codex-like coding loop around free or free-tier inference providers. It is not a free Claude subscription and it does not turn a provider's paid proprietary models into a free service.

The model sees repository tool results, not GitHub MCP credentials or provider API keys.

The agent deliberately does not expose:

```text
.env*
.pem
.key
.git/
node_modules/
.dart_tool/
build/
```

and it blocks network-capable shell commands such as `curl`, `wget`, and `ssh`.

## 7. Verification

The contract test is dependency-free:

```bash
node --check tools/free-llm-agent.mjs
node --test tools/tests/free-llm-agent.test.mjs
```

A dedicated GitHub Actions workflow runs those two checks for changes to the agent.

## Sources

- `https://github.com/mnfst/awesome-free-llm-apis`
- `https://github.com/mnfst/awesome-free-llm-apis/blob/main/free-llm-apis/SKILL.md`
- `https://console.groq.com/docs/openai`
