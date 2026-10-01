# Glossary

Short on purpose: just enough to recognise what a term means. Look elsewhere for depth.

## Models

| Term | What it is |
|---|---|
| **LLM** | A large language model: a neural network that predicts the next token. "The model." |
| **Parameters (7B, 27B…)** | The model's learned numbers, in billions. More parameters usually means smarter, bigger and slower. |
| **MoE (Mixture of Experts)** | A model where only part of the network runs per token, e.g. "35B-A3B" = 35B total, 3B active. Fast like a small model, but it needs memory like a big one. |
| **Token** | A piece of text (about ¾ of a word) that models read and write. Speed and context are measured in tokens. |
| **Context window (ctx, `-c`)** | How many tokens a model can consider at once: prompt + history + answer. Agents need 32k+. |
| **Training context** | The longest context the model was trained on. Going above it gives worse results, so llama.cpp caps it. |
| **Weights** | The file(s) holding the parameters. This is what you download. |
| **GGUF** | llama.cpp's model file format: a single file with weights plus metadata (chat template, tokenizer). |
| **Quantization (Q4_K_M, Q8_0…)** | Storing weights with fewer bits to save memory. Q8 is near-lossless; Q4_K_M is the common sweet spot, about ¼ the size of the original. |
| **mmproj** | An extra GGUF file that lets a model see images or hear audio (a multimodal projector). |
| **Chat template** | The model-specific format that turns a list of messages into the text the model actually sees. Wrong template means garbled answers or broken tool calls. |
| **Jinja (`--jinja`)** | The template language chat templates are written in. llama.cpp needs it for tool calling (on by default). |
| **Tool calling / function calling** | The model answers with a structured "call this tool with these arguments" instead of text. Agents depend on it. |
| **Thinking / reasoning** | Some models write hidden reasoning before the answer. That costs tokens and time. |
| **LoRA** | A small add-on trained on top of a base model. vLLM can serve many LoRAs on one base model. |
| **Hugging Face (HF)** | The main site for downloading models. `ggml-org` is the llama.cpp team's account there. |
| **HF cache** | `~/.cache/huggingface/hub/`, where `-hf` downloads go. Router mode finds models here. |

## Running models (inference)

| Term | What it is |
|---|---|
| **Inference** | Running a model to get answers, as opposed to training it. |
| **Inference engine / server** | The program that loads weights onto the GPU and serves requests: llama.cpp, MLX, vLLM, Ollama. |
| **llama.cpp** | An open-source C/C++ inference engine. Runs GGUF models on CPU or GPU (Metal on Mac). Our choice. |
| **llama-server** | llama.cpp's HTTP server. Exposes the OpenAI- and Anthropic-compatible APIs and a web UI. |
| **Router mode** | `llama-server` started *without* a model. It loads models on demand by name, keeps up to `--models-max` loaded, and unloads the least recently used. |
| **Preset (`models.ini`)** | The router's model list: a short name per model plus that model's settings (context, slots…). |
| **MLX** | Apple's machine-learning framework for Apple silicon. `mlx-lm` is its LLM server. |
| **vLLM** | A production inference server for many concurrent users on GPU servers. |
| **vllm-metal** | A community plugin in the official vLLM project that runs vLLM on a Mac, using MLX. |
| **Ollama** | A friendly wrapper around llama.cpp (moving to MLX on Mac). Easy, but hides the settings. |
| **Metal** | Apple's GPU API. "Metal backend" means the model runs on the Mac's GPU. |
| **Unified memory** | On Apple silicon, CPU and GPU share one memory pool. The model has to fit in the GPU's share of it. |
| **GPU wired limit** | How much unified memory the GPU may use (`iogpu.wired_limit_mb`). Measured on this Mac: 25.5 GB. |
| **Prefill (prompt processing)** | Reading the prompt. It is measured in tokens/s and decides time-to-first-token. |
| **Generation (decode)** | Writing the answer token by token. Its tokens/s is the "speed" people quote. |
| **TTFT** | Time to first token: how long until the answer starts. Prefill dominates it. |
| **KV cache** | The model's working memory for a conversation in progress. It grows with context and uses GPU memory. |
| **Slot (`-np`)** | One request-in-progress inside llama-server. 2 slots = 2 parallel requests per model. |
| **Continuous batching** | Mixing several requests into the same GPU work, so parallel users don't wait in line. |
| **Prompt / prefix caching** | Reusing the computed start of a prompt (e.g. a shared system prompt) instead of recomputing it. |
| **PagedAttention** | vLLM's way of storing the KV cache in pages, so many more conversations fit in memory. |
| **Speculative decoding** | A small "draft" model guesses tokens and the big model checks them. Faster when the guesses are good. |

## APIs and routing

| Term | What it is |
|---|---|
| **OpenAI-compatible API** | The de facto standard request format (`/v1/chat/completions`, `/v1/models`). Almost every tool speaks it. |
| **Anthropic Messages API** | Anthropic's format (`/v1/messages`). llama-server speaks it too, so Claude Code can use it. |
| **Endpoint** | The URL a client calls. Ours is `http://127.0.0.1:8080`. |
| **API key** | A shared secret sent as `Authorization: Bearer <key>`. Without it, llama-server answers `401`. |
| **CORS** | The browser rule for which web pages may call an API. Restricted to localhost here, so random websites can't use the server. |
| **Semantic router** | A layer in front of several models that picks one per request based on what is asked. |
| **llm-d** | A Kubernetes stack that routes requests across many vLLM replicas, cache- and load-aware. |
| **Envoy AI Gateway / Agent Router** | An AI-aware API gateway (we use it at work). It was renamed Agent Router in September 2026. |

## macOS service

| Term | What it is |
|---|---|
| **launchd** | macOS's service manager, the equivalent of systemd on Linux. It starts, stops and restarts programs. |
| **LaunchAgent** | A launchd job that runs as *your user*, after you log in. Lives in `~/Library/LaunchAgents/`. Ours is one. |
| **LaunchDaemon** | A launchd job that runs as root at *boot*, before anyone logs in. Lives in `/Library/LaunchDaemons/`. |
| **plist** | The XML file describing a launchd job: what to run, with which arguments, and when. |
| **launchctl** | The CLI for launchd: `bootstrap` (load), `bootout` (unload), `print` (status), `kickstart -k` (restart). |
| **Label** | A launchd job's unique name. Ours is `local.llm-inference.llama-server`. |
| **KeepAlive** | A plist key: restart the program if it exits or crashes. |
| **Prometheus metrics (`/metrics`)** | Numbers about the server (requests, tokens/s, slots) in a format monitoring tools scrape. |
