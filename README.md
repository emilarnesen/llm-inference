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

## Quick usage

```sh
./scripts/install-service.sh          # once: API key + launchd service
llm status                            # after putting scripts/llm on PATH (see docs/usage.md)
llm load gemma-4-e2b | llm unload-all | llm stop | llm start
```

## Current choice

**llama.cpp `llama-server` in router mode** on the Mac, as an always-on but lightweight service:
about 75 MB when idle, with models loaded from disk on the first request and unloaded after 15
idle minutes. **vllm-metal** is planned as an on-demand experiment for many parallel requests.
How the two fit together is in [docs/serving.md](docs/serving.md). The reasons are in
[docs/engines.md](docs/engines.md) and
[docs/decisions/0001-llama-cpp-first.md](docs/decisions/0001-llama-cpp-first.md).

## Documentation

| Doc | Contents |
|---|---|
| [docs/glossary.md](docs/glossary.md) | **Start here if a word is unfamiliar**: models, inference, APIs, launchd |
| [docs/usage.md](docs/usage.md) | **Daily use**: the `llm` helper and putting it on PATH, adding models, calling the API |
| [docs/serving.md](docs/serving.md) | Why router mode (light, on demand), model lifecycle, where vllm-metal fits |
| [docs/setup-macos.md](docs/setup-macos.md) | Install llama.cpp, router mode, launchd service, API key |
| [docs/engines.md](docs/engines.md) | Ollama vs llama.cpp vs MLX vs vLLM, verified 2026-10-01, with sources |
| [docs/vision.md](docs/vision.md) | Many parallel agents: batching, prefix caching, semantic routing, llm-d |
| [docs/decisions/](docs/decisions/) | Architecture decisions (ADRs) |

## Status

- [x] Engine comparison and decision
- [x] Install llama.cpp, smoke test on Metal (25.5 GB GPU budget)
- [x] Router preset ([router/models.ini](router/models.ini)) and launchd service ([scripts/install-service.sh](scripts/install-service.sh))
- [ ] Choose models (tool calling, context length, fit in 25.5 GB including the KV cache)
- [ ] OpenShell profile + provider for the local endpoint (in agent-sandbox)
- [ ] vllm-metal concurrency experiment

## Repository layout

```
docs/                     glossary, setup, engine comparison, vision, decisions
router/models.ini         the models the server offers, by short name
launchd/                  launchd plist template for the service
scripts/                  install-service.sh / uninstall-service.sh / llm (status, load, unload, stop, start)
```
