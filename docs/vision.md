# Long-term direction: many agents, many models

This is a "big thinking" scenario. It may never be built in full, but it explains why the repo
looks the way it does.

## The scenario

Small, task-specific agents, each in its own sandboxed environment (see
[agent-sandbox](https://github.com/emilarnesen/agent-sandbox)), are started by **events**. The
events can be anything: something in the tech stack, a webhook, a calendar entry, something
happening in real life. Agents start at random times, often several in parallel, and stop when
their task is done.

## What that means for inference

- **Every agent is a "user."** Many agents in parallel means many concurrent users, arriving in
  bursts.
- **Agents are heavy users.** One agent is not one request. It loops: think, call a tool, read the
  result, think again. Ten agents can mean dozens of requests in flight.
- **Agents share a lot of text.** Agents of the same type get the same system prompt and tool
  definitions every time. **Prefix caching** reuses that work, so every new agent starts cheaper.
- **Memory is the limit.** Every conversation in progress holds a KV cache. Fitting many of them is
  what PagedAttention solves.
- **Not every task needs the same model.** A **semantic router** in front of the engines can choose
  per request: a small, fast model for simple classification, a large one for hard reasoning.

That is the job vLLM was built for. Local engines (llama.cpp, MLX) handle a few parallel requests,
not a fleet.

## The pieces, as of 2026-10

| Layer | Example | Notes |
|---|---|---|
| Engine | **vLLM**, SGLang | One model per process. Continuous batching, PagedAttention, prefix caching, multi-LoRA. |
| Fleet routing | **llm-d** (Red Hat, Google, IBM, CoreWeave, NVIDIA; CNCF Sandbox) | Routes across vLLM replicas with prefix-cache and load awareness, via the Gateway API Inference Extension. |
| Model choice | **vLLM Semantic Router** (v0.4.0) | Classifies each request and picks a model. Also does PII detection, prompt guarding and semantic caching. Runs as an Envoy ExtProc service. |
| Gateway | **Agent Router**, formerly Envoy AI Gateway | Provider translation, credentials and rate limits. Semantic Router has documented integration with v1.0.x. |

Notes on these pieces:

- **Agent Router:** Envoy AI Gateway reached v1.0 GA on 2026-06-23. On 2026-09-10 it joined the
  Agentic AI Foundation and was renamed Agent Router. Work currently runs Envoy AI Gateway v0.6.0,
  and whether Semantic Router works with v0.6.0 is unverified.
- **TGI** (Hugging Face) is archived. Hugging Face itself recommends vLLM, SGLang, llama.cpp or MLX.

## Where each part is learned

| | Mac mini (now) | Linux / GPU (later) |
|---|---|---|
| Engine | llama.cpp router mode, then vllm-metal | vLLM on a real GPU, or the vLLM backend at work |
| Learn | Model choice, the API contract, a handful of parallel agents, a first vLLM concurrency test | Real concurrency, batching and prefix-cache economics |
| Routing | Router mode or a simple proxy across local models | Semantic Router + Agent Router / Envoy AI Gateway, llm-d |
| Agents | A few OpenShell sandboxes | An event-driven fleet (e.g. `kubernetes-sigs/agent-sandbox` warm pools) |

## Sources

- https://github.com/vllm-project/semantic-router · https://vllm-sr.ai/docs/installation/k8s/ai-gateway/
- https://docs.vllm.ai/projects/production-stack/en/latest/use_cases/semantic-router-integration.html
- https://github.com/llm-d/llm-d · https://github.com/sgl-project/sglang
- https://theagentrouter.ai/release-notes/v1.0/ · https://aaif.io/blog/agent-router-joins-aaif
- https://github.com/huggingface/text-generation-inference
