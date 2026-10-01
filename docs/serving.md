# How models are served on the Mac

This doc covers two engines with two different jobs:

- **llama-server in router mode** is the everyday service. It is light when idle and loads models
  only when asked.
- **vllm-metal** is an on-demand experiment for many parallel requests.

Both expose the same OpenAI-compatible API on `127.0.0.1`, so clients only change the URL.

```
clients (agents in OpenShell sandboxes, curl, web UI)
   │  Authorization: Bearer <key>,  "model": "<name>"
   ▼
llama-server router  :8080   always on, ~75 MB, no model of its own
   ├─ model process "gemma-4-e2b"    started on first request, stopped after 15 idle minutes
   └─ model process "<next model>"   at most 2 at once (--models-max 2), least recently used unloaded

vllm-metal           :8000   started by hand for experiments, one model, stopped afterwards
```

## Why router mode

The Mac mini is a shared machine. It runs the lab, but it is also used for everything else.
Router mode fits that, because it only costs resources while a model is actually in use.

| Property | What it means here | Measured / source |
|---|---|---|
| **Light when idle** | The router holds no model. It is just an HTTP process that knows which models exist. | ~**75 MB** RAM, ~0% CPU (2026-10-01) |
| **Loads on demand** | A model starts as its own process on the first request that names it. It is read from local disk, not downloaded. | gemma-4-e2b Q8: ~10–20 s to load, then ~**5.9 GB** |
| **Unloads when idle** | After 15 idle minutes (`--sleep-idle-seconds 900`), the model process stops and its GPU memory is free again. `llm unload-all` does it immediately. | |
| **Several models, one endpoint** | Clients pick a model by name. Up to `--models-max 2` stay loaded, and the least recently used is unloaded when a third is asked for. That keeps us inside the **25.5 GB** GPU budget. | `llama-server --list-devices` |
| **One process per model** | Each model runs in its own child process with its own settings from `router/models.ini`. One model crashing does not take down the others or the router. | llama.cpp server README |
| **One place to configure** | Which models exist, and their context and slots, is versioned in [`router/models.ini`](../router/models.ini). The key, port and CORS settings live in the launchd plist. | |
| **Same API for everything** | OpenAI and Anthropic APIs, so OpenCode, Claude Code and curl all work unchanged. | |

### A model's lifecycle

| State | What happens | Cost |
|---|---|---|
| **Not downloaded** | Unknown to the router. Requests for it fail. | 0 |
| **On disk** (HF cache) | Listed by the router as `unloaded`. | Disk only (GB) |
| **Loading** | The first request, or `llm load`, starts a model process. That request waits. | Seconds |
| **Loaded** | It answers requests, up to `np` in parallel. | GPU memory: weights + KV cache |
| **Idle → unloaded** | After 15 minutes without requests, the process stops. | Back to disk only |

### The trade-offs

- **The first request after idle is slow**, because it includes the load time. That is fine for
  agents, but noticeable in an interactive chat.
- **Download first, then add to the preset.** Downloading is a separate step:
  `llama download -hf <repo>:<quant>`. A preset entry for a model not yet on disk would make the
  first request trigger the download (minutes), which may time out. Untested, and best avoided.
- **Memory adds up.** `--models-max 2` means two models *plus* their KV caches must fit in
  25.5 GB at once.
- **`c` is shared across slots.** In `models.ini`, `c = 65536` with `np = 2` gives 32k tokens per
  request.

## Where vllm-metal fits

vLLM makes the opposite trade-off. It is built to be **busy all the time** with many users:

- **It reserves GPU memory up front.** Like vLLM on GPUs, it allocates a fixed KV-cache pool at
  startup (sized by `--gpu-memory-utilization`). That pool is what makes continuous batching and
  PagedAttention efficient, but it is held whether or not anyone is asking.
- **One model per process.** There is no router that loads and unloads models by name.
- **What it is good at:** many requests in parallel (continuous batching), and prefix caching.
  Agents sharing the same system prompt reuse its computation. That is the
  [many-agents scenario](vision.md).

So vllm-metal is **not** the everyday service on a shared Mac. We use it as an on-demand
experiment:

1. Free the GPU: `llm unload-all`, or `llm stop`.
2. Start `vllm serve <model> --port 8000` by hand, with the same model as in llama.cpp.
3. Run the same load against both: 1, 4, 8, 16 parallel "agents", with and without a shared prefix.
4. Stop vLLM and run `llm start`.

What it teaches: how batching and prefix caching behave under load, on the **same `vllm serve`
CLI and flags as production**. At work, the vLLM backend on OpenShift AI is run this way. On the
Mac it is a young community plugin, so treat the results as learning, not as a benchmark of real
GPUs.

## Side by side

| | llama-server router | vllm-metal |
|---|---|---|
| Role | Everyday service | On-demand experiment |
| Idle cost | ~75 MB, no GPU memory | GPU memory reserved while running |
| Models | Many, loaded and unloaded by name | One per process |
| Parallel requests | A few (slots per model) | Many (continuous batching, paged KV cache) |
| Prefix caching | Prompt cache per slot | Automatic, shared across requests |
| Runs | Always (launchd), cheap | Only during experiments |
| Port | 8080 | 8000 |
| Status | Installed, tested | Not installed yet |
