# llm-inference

Running language models myself: choosing engines and models, serving them as an API, and
learning how inference scales from one Mac to many concurrent agents.

The first target is a Mac mini (Apple M6, 32 GB unified memory) serving local models to coding
agents that run in sandboxes ([agent-sandbox](https://github.com/emilarnesen/agent-sandbox)). The
long-term direction is many small, event-driven agents in parallel, which is vLLM territory (see
[docs/vision.md](docs/vision.md)).

## The contract

This repo provides **an OpenAI- and Anthropic-compatible endpoint on `127.0.0.1`**. Whatever
engine sits behind it can change. The sandbox side only needs the endpoint and a model name.

## Current choice

**llama.cpp `llama-server` in router mode** on the Mac. It serves several models, loading them on
demand. **vllm-metal** is planned as a second experiment. The reasons are in
[docs/engines.md](docs/engines.md) and
[docs/decisions/0001-llama-cpp-first.md](docs/decisions/0001-llama-cpp-first.md).

## Documentation

| Doc | Contents |
|---|---|
| [docs/engines.md](docs/engines.md) | Ollama vs llama.cpp vs MLX vs vLLM, verified 2026-10-01, with sources |
| [docs/vision.md](docs/vision.md) | Many parallel agents: batching, prefix caching, semantic routing, llm-d |
| [docs/decisions/](docs/decisions/) | Architecture decisions (ADRs) |

## Status

- [x] Engine comparison and decision
- [ ] Choose models (tool calling, context length, fit in about 20–24 GB of GPU memory)
- [ ] Install llama.cpp, write the router preset and launchd service
- [ ] OpenShell profile + provider for the local endpoint (in agent-sandbox)
- [ ] vllm-metal concurrency experiment
