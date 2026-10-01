# 0001 — llama.cpp `llama-server` (router mode) as the Mac's inference engine; vllm-metal second

**Date:** 2026-10-01 · **Status:** accepted

## Context

The Mac mini (M6, 32 GB) will serve local models to coding agents running in OpenShell sandboxes.
The workload needs:

- tool calling
- long context
- several parallel requests
- more than one model

Candidates were Ollama, llama.cpp, MLX (`mlx-lm`) and vLLM (`vllm-metal`). The comparison is in
[../engines.md](../engines.md).

## Decision

- **Primary:** llama.cpp `llama-server` in **router mode**. It serves several GGUF models, loading
  them on demand. It exposes an OpenAI- and Anthropic-compatible API on localhost and runs as a
  launchd service.
- **Second experiment:** vllm-metal, running the same model, to measure concurrency and prefix
  caching and to learn vLLM on the same CLI as production.
- **Not chosen:**
  - Ollama hides the knobs we want to learn, and its defaults are wrong for agents.
  - `mlx-lm` as the server: it keeps one model loaded at a time, its tool calling is fragile, and
    it is weak on long context. It stays a candidate for speed comparisons.

## Consequences

- Models are GGUF files in a folder we control. That folder belongs on the external SSD when it is
  connected.
- We write and version our own launchd plist and router preset (per-model settings) in this repo.
- The contract with [agent-sandbox](https://github.com/emilarnesen/agent-sandbox) is an
  OpenAI- and Anthropic-compatible endpoint on `127.0.0.1`. Swapping engines later does not affect
  the sandbox side.
- On short prompts, MLX may be faster. Revisit this decision if llama.cpp's speed on the M6 turns
  out to be the bottleneck.
