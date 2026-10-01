# Inference engines compared

**Checked:** 2026-10-01 · **Target:** Mac mini M6, 32 GB unified memory, macOS 27 · **Workload:**
coding agents in sandboxes. They need tool calling, long context (often 30k+ tokens), several
requests in parallel, and more than one model.

Everything below was verified against primary sources (repos, release notes, docs) on the date
above. Items marked *unverified* had no source. No M6-specific benchmarks exist yet for any engine.

## The short version

| | Ollama | llama.cpp `llama-server` | MLX (`mlx-lm`) | vLLM (`vllm-metal` on Mac) |
|---|---|---|---|---|
| What it is | A friendly wrapper and service around llama.cpp, moving to MLX on Mac | The engine itself: C/C++, Metal, GGUF models | Apple's ML framework and its LLM server | A production GPU server, with a Mac plugin built on MLX |
| Latest | v0.35.0 (v0.40 RC runs MLX by default) | v0.5.0 / b11327 | mlx-lm v0.32.0 | vLLM v0.30.0 · vllm-metal v0.30.0 |
| Several models | On demand, 3 loaded at a time | **Router mode**: on demand, up to 4 loaded, LRU unload | On demand, but **only 1 loaded** (each swap is a cold reload) | One model per process; several models need a router in front |
| Parallel requests | Default **1** (`OLLAMA_NUM_PARALLEL`) | Continuous batching, auto slots | Continuous batching (32 decode / 8 prefill) | Continuous batching and a paged KV cache, built for this |
| Prefix / prompt cache | No (Anthropic API) | Yes (`--cache-ram`, 8 GiB default) | Yes (LRU) | Yes (automatic prefix caching) |
| Tool calling | Yes, with gaps (`tool_choice` is missing) | Mature (`--jinja`, on by default) | **Fragile**: open issues for several model families | Parsers per model family (*unverified* on Metal) |
| Long context | Default context 4k–32k; agents need ≥64k | **Strongest** on long context | **Weak spot**: about 50% slower than llama.cpp at 100k+ tokens | *Unverified* on Metal |
| APIs | OpenAI + Anthropic | OpenAI + Anthropic (Claude Code works) | OpenAI | OpenAI |
| Model format | Own blob store | GGUF | MLX safetensors (mlx-community) | Hugging Face / MLX |
| Service on Mac | `brew services` | Own launchd plist | Own launchd plist | Own launchd plist |
| Licence | MIT | MIT | MIT | Apache 2.0 |
| Maturity on Mac | High | High | High, but its maintainers say it is "not for production" | **Young** community plugin, no published benchmarks |

## Each engine in brief

### Ollama: the easy one

- **Good:** easiest to install and run as a service. Models load on demand. It has both APIs. It is
  moving to an MLX engine on Mac (v0.40 RC).
- **Bad:**
  - Its defaults are wrong for agents: **1** parallel request, and a small default context that
    the docs themselves say should be at least 64k for coding agents.
  - Context can only be changed via a Modelfile or env var, not through the OpenAI API.
  - Models live in hashed blobs that no other tool can read.
  - It ships fast, often-changing releases with cloud and account features pushed in.
- **Verdict:** a wrapper around engines we can use directly. It hides exactly the knobs we want to
  learn.

### llama.cpp `llama-server`: the engine under Ollama

- **Good:**
  - **Router mode**, built in since December 2025: start it without a model, and it serves every
    GGUF in a folder. It loads models on demand, keeps up to N loaded and unloads idle ones.
  - Continuous batching and a prompt cache are on by default.
  - The most mature tool calling.
  - Best long-context performance on Apple silicon.
  - OpenAI **and** Anthropic APIs, plus `--metrics` (Prometheus) and `--api-key`.
- **Bad:**
  - You tune the flags yourself.
  - There is no Homebrew service, so it needs our own launchd plist.
  - GGUF only.
  - On short contexts, token generation is usually somewhat slower than MLX.
- **Related:** [llama-swap](https://github.com/mostlygeek/llama-swap) is a proxy that loads and
  swaps models on demand. It is less necessary now that router mode exists. If used, it must be
  **v260 or later**: v260 fixed a startup crash on macOS 27 / M6.

### MLX (`mlx-lm`): Apple's own

- **Good:**
  - The fastest prefill on M5-class chips and newer (Apple: 3.3–4× faster time-to-first-token than
    M4).
  - Generation on short and medium contexts is usually faster than llama.cpp.
  - New models are often supported on day one.
- **Bad:**
  - Only one model loaded at a time.
  - Tool calling is fragile: open issues for Qwen 3.5 around 20k tokens, Gemma 4, Mistral and
    others.
  - Long-context generation trails llama.cpp.
  - Its own docs say it is not for production.
  - Big models need `sudo sysctl iogpu.wired_limit_mb=…`, which resets at reboot.
- **Related:**
  - [vllm-mlx](https://github.com/waybarrios/vllm-mlx) is a separate, young project. It adds a
    paged KV cache, batching, the Anthropic API and a multi-model registry on top of MLX.
  - The LM Studio app is closed source; only its `mlx-engine` is open.

### vLLM: the production server

- **What it is for:** many concurrent users on GPU servers.
  - **Continuous batching:** many requests share each GPU step.
  - **PagedAttention:** the KV cache, each conversation's working memory, is stored in pages, so
    more conversations fit.
  - **Automatic prefix caching:** agents that share a system prompt reuse its computation.
  - **Multi-LoRA:** many small fine-tuned adapters on one base model.
- **One base model per process.** Several models means several processes plus a router in front.
- **On a Mac:** [vllm-metal](https://github.com/vllm-project/vllm-metal) is a community plugin in
  the official vllm-project org, using MLX as its compute backend.
  - It ships paged attention, prefix caching and batching.
  - It is young, there are no published benchmarks, and some features are rejected (quantized KV
    cache dtypes).
  - The upstream CPU backend on macOS is experimental and FP16/FP32 only, so it is not useful.
- **Why it still matters here:** `vllm serve` is the same CLI and flags as production, for example
  the vLLM backend on OpenShift AI at work. It is also the engine the
  [scenario](vision.md) of many parallel agents needs.

## Recommendation

**Primary: llama.cpp `llama-server` in router mode.** The agent workload is long context, tool
calls, several requests in parallel and several models. llama.cpp is the most mature engine on all
four. MLX is fastest on short prompts, but its weak spots (one model loaded, fragile tool calls,
slow long context) are exactly what agents hit.

Router mode also suits a **shared Mac**. The idle router uses about 75 MB and holds no model.
Models load from disk on the first request and unload after 15 idle minutes. How this works, with
measurements, is in [serving.md](serving.md).

**Second experiment: vllm-metal.** Run the same model on both engines and measure concurrency (many
parallel agents) and prefix-cache effects. This is how we learn vLLM's concepts locally, on the
same CLI as production, before Track B on real GPUs. vLLM reserves GPU memory up front and serves
one model per process, so it runs **on demand during experiments**, not as the everyday service.
See [serving.md](serving.md#where-vllm-metal-fits).

**Not chosen:** Ollama. It hides the knobs we want to learn. Plain `mlx-lm` is not chosen as the
server either, but it stays a candidate for a speed comparison.

The decision is recorded in [decisions/0001-llama-cpp-first.md](decisions/0001-llama-cpp-first.md).

## Sources

- Ollama: https://github.com/ollama/ollama/releases · https://ollama.com/blog/mlx ·
  https://docs.ollama.com/faq · https://docs.ollama.com/context-length ·
  https://docs.ollama.com/api/anthropic-compatibility
- llama.cpp: https://github.com/ggml-org/llama.cpp/releases/tag/v0.5.0 ·
  https://huggingface.co/blog/ggml-org/model-management-in-llamacpp ·
  https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md ·
  https://huggingface.co/blog/ggml-org/anthropic-messages-api-in-llamacpp ·
  https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md ·
  https://github.com/mostlygeek/llama-swap/releases
- MLX: https://github.com/ml-explore/mlx-lm · https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md ·
  https://machinelearning.apple.com/research/exploring-llms-mlx-m5 ·
  https://github.com/ml-explore/mlx-lm/issues/763 · https://github.com/waybarrios/vllm-mlx
- vLLM: https://github.com/vllm-project/vllm/releases · https://github.com/vllm-project/vllm-metal ·
  https://docs.vllm.ai/en/latest/getting_started/installation/cpu/
