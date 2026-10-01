# Usage

Day-to-day use of the local model service. To install it first, see
[setup-macos.md](setup-macos.md).

## The scripts

All scripts live in [`scripts/`](../scripts/) and run from the repo. Nothing is installed globally
except the launchd service itself.

| Script | When | What it does |
|---|---|---|
| `install-service.sh` | Once, or after editing the plist template | Creates the API key (first time only), installs the launchd service and starts it |
| `uninstall-service.sh` | To remove the service | Stops and removes it. Models, logs and the key are kept. |
| `llm` | Daily | Status, load and unload models, stop and start the service, logs |

### Put `llm` on your PATH (once)

So you can type `llm` from anywhere instead of `~/code/llm-inference/scripts/llm`. Pick one:

**A. A personal bin folder** (recommended; reusable for other tools):

```sh
mkdir -p ~/.local/bin
ln -s ~/code/llm-inference/scripts/llm ~/.local/bin/llm
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc     # only if ~/.local/bin is not already on PATH
exec zsh                                                    # reload the shell
```

**B. The repo's scripts folder:**

```sh
echo 'export PATH="$HOME/code/llm-inference/scripts:$PATH"' >> ~/.zshrc
exec zsh
```

Both are symlinks or paths into the repo, so `git pull` updates the command automatically. Check
with `which llm`.

## Everyday commands

```sh
llm status              # is the service running, which models are loaded, memory per process
llm load gemma-4-e2b    # load a model now (otherwise it loads on the first request)
llm unload gemma-4-e2b  # unload it and free the memory
llm unload-all          # free the GPU, e.g. before gaming, video export or a big build
llm stop                # turn the service off, and keep it off across logins
llm start               # turn it back on
llm restart             # after editing router/models.ini
llm logs                # follow the log (Ctrl+C to quit)
```

## Adding a model

1. **Check that it fits** (weights + KV cache must fit in 25.5 GB, together with any other loaded
   model): `llama fit-params --help`.
2. **Download it:** `llama download -hf <repo>:<quant>`. Always do this first, so no request has to
   wait for a download.
3. **Add a section** to [`router/models.ini`](../router/models.ini). The section name is the name
   clients use:
   ```ini
   [my-model]
   hf-repo = <repo>:<quant>
   ```
4. **Reload:** `llm restart`, then `llm status` shows it as `unloaded`, ready to use.
5. **Commit** the `models.ini` change.

## Calling the API

The endpoint is `http://127.0.0.1:8080`, and every request needs the API key:

```sh
KEY=$(head -1 ~/.config/llm-inference/api-keys)

curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:8080/v1/models

curl -s -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  http://127.0.0.1:8080/v1/chat/completions \
  -d '{"model":"gemma-4-e2b","messages":[{"role":"user","content":"Say hi"}]}'
```

| Want | Use |
|---|---|
| A chat in the browser | http://127.0.0.1:8080 (the built-in web UI; asks for the key) |
| A chat in the terminal against the running server | `llama-cli --server-base http://127.0.0.1:8080` (key handling unverified) |
| OpenAI-style clients and SDKs | Base URL `http://127.0.0.1:8080/v1`, API key = the key, model = a preset name |
| Anthropic-style clients | `POST /v1/messages` on the same server |
| Metrics | `curl -s -H "Authorization: Bearer $KEY" "http://127.0.0.1:8080/metrics?model=gemma-4-e2b"` |

Agents in OpenShell sandboxes never see this key. A provider in
[agent-sandbox](https://github.com/emilarnesen/agent-sandbox) holds it, and the supervisor injects
it, just like the OpenRouter key.

## Where things are

| What | Where |
|---|---|
| Models (downloaded) | `~/.cache/huggingface/hub/` |
| Model list and per-model settings | `router/models.ini` (this repo) |
| API key | `~/.config/llm-inference/api-keys` (mode 600, not in git) |
| Service definition | `~/Library/LaunchAgents/local.llm-inference.llama-server.plist` (generated from `launchd/`) |
| Logs | `~/Library/Logs/llm-inference/llama-server.log` |
