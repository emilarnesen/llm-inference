# Setup on macOS: llama-server as a router service

**Tested:** 2026-10-01 on a Mac mini M6 (32 GB), macOS 27, llama.cpp 0.5.0 (build 11146).

The result: `llama-server` in **router mode**, always running as a **launchd user agent**, on
`http://127.0.0.1:8080`. It requires an API key and loads models by name on demand.

## 1. Install llama.cpp

```sh
brew install llama.cpp
llama-server --version
llama-server --list-devices      # should show MTL0: Apple M6 (… MiB free) = the GPU
```

Official docs: [install](https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md) ·
[llama-server](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) ·
[router mode](https://huggingface.co/blog/ggml-org/model-management-in-llamacpp) ·
[tool calling](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md)

## 2. Download a model

Models are downloaded from Hugging Face into `~/.cache/huggingface/hub/`. Without a `:tag`, the
`Q4_K_M` file is picked, or the first file if that does not exist. Always download **before**
adding a model to the preset, so no request ever has to wait for a download.

```sh
llama download -hf ggml-org/gemma-4-E2B-it-GGUF:Q8_0     # download only
llama fit-params --help                                  # computes what fits in GPU memory
```

`llama` is llama.cpp's combined command (`serve`, `cli`, `download`, `bench`, `fit-params`…;
see `llama help all`). After downloading, add the model to the preset and run `llm restart`.

## 3. Add it to the router preset

[`router/models.ini`](../router/models.ini) lists the models the API serves, by short name:

```ini
[*]                     ; defaults for every model
c = 65536               ; TOTAL context, split across slots → 32k per request
np = 2                  ; parallel requests per model (slots)

[gemma-4-e2b]           ; the name clients use: "model": "gemma-4-e2b"
hf-repo = ggml-org/gemma-4-E2B-it-GGUF:Q8_0
```

After editing the preset, restart the service (step 5).

## 4. Install the service

```sh
./scripts/install-service.sh
```

The script:

1. Creates an API key in `~/.config/llm-inference/api-keys` (once; mode 600, never committed).
1. Downloads the web UI files for the installed llama.cpp build to
   `~/.local/share/llm-inference/ui/b<build>/` (see the gotcha below).
2. Renders [`launchd/llama-server.plist.template`](../launchd/llama-server.plist.template) into
   `~/Library/LaunchAgents/local.llm-inference.llama-server.plist`.
3. Loads it with `launchctl`. The service starts now and at every login, and restarts if it
   crashes.

What the service runs:

| Flag | Why |
|---|---|
| `--host 127.0.0.1 --port 8080` | Only reachable from this Mac. The port is pinned, because the default port changes in a future release. |
| `--models-preset …/router/models.ini` | Router mode with our model list, read straight from this repo. |
| `--models-max 2` | At most 2 models in memory (25.5 GB GPU budget). The least recently used one is unloaded. |
| `--sleep-idle-seconds 900` | Unload models after 15 idle minutes. |
| `--api-key-file …` | Every request needs `Authorization: Bearer <key>`. |
| `--cors-origins localhost` | Web pages on other sites can't call the server from your browser. |
| `--metrics` | Prometheus metrics at `/metrics`. |
| `--path …/ui/b<build>` | Serves the web UI files, which the Homebrew bottle lacks. |

## 5. Check, use, restart

The [`scripts/llm`](../scripts/llm) helper wraps the API and launchctl:

```sh
llm status            # service state, every model (loaded/unloaded), memory per process
llm load gemma-4-e2b  # load now (otherwise: on first request)
llm unload gemma-4-e2b
llm unload-all        # free the GPU memory, e.g. before something heavy
llm stop              # turn the service off, and keep it off across logins
llm start             # turn it back on
llm restart           # after editing router/models.ini
llm logs
```

To put `llm` on your PATH, and for daily use (adding models, calling the API), see
[usage.md](usage.md).

**Resource use (measured):** the router alone uses about 75 MB of RAM and ~0% CPU. No model is
loaded at startup. A model loads on its first request as a separate process (gemma-4-e2b Q8: about
5.9 GB) and is unloaded after 15 idle minutes.

The same things by hand:

```sh
KEY=$(head -1 ~/.config/llm-inference/api-keys)

curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:8080/v1/models
curl -s -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  http://127.0.0.1:8080/v1/chat/completions \
  -d '{"model":"gemma-4-e2b","messages":[{"role":"user","content":"Say hi"}]}'

launchctl print gui/$(id -u)/local.llm-inference.llama-server | grep -E 'state|pid'
launchctl kickstart -k gui/$(id -u)/local.llm-inference.llama-server     # restart
tail -f ~/Library/Logs/llm-inference/llama-server.log                    # logs
./scripts/uninstall-service.sh                                           # remove
```

The web UI is at http://127.0.0.1:8080. It asks for the API key.

## Notes and gotchas

- **The web UI is missing from Homebrew's llama.cpp 0.5.0.** `http://127.0.0.1:8080` returns
  `{"error":{"message":"File Not Found",…}}` (open issue
  [homebrew-core#314191](https://github.com/Homebrew/homebrew-core/issues/314191), fix
  [PR #314732](https://github.com/Homebrew/homebrew-core/pull/314732) not merged as of
  2026-10-02). The workaround is the official `llama-b<build>-ui.tar.gz` from the matching
  [llama.cpp release](https://github.com/ggml-org/llama.cpp/releases), served with `--path`.
  `install-service.sh` does this. **Re-run it after `brew upgrade llama.cpp`**, so the UI matches
  the new build.

- **LaunchAgent, not LaunchDaemon:** the service starts at *login*, not at boot. On an always-on
  Mac, that means auto-login, or later a LaunchDaemon. This ties into the external SSD's
  encryption-vs-boot decision.
- **Models in the HF cache** live on the internal disk for now. To move them to the external SSD,
  set `LLAMA_CACHE` (or `HF_HOME`) in the plist.
- **`c` is the total context, shared by all slots.** With `c = 32768` and `np = 2`, each request
  only gets 16k tokens (the log shows `n_ctx_slot = 16384`). We use `c = 65536`.
- **`llama-cli`** is a standalone terminal chat. It loads its *own* copy of a model and does not
  talk to the server.
- **A first request to an unloaded model is slow**, because the model is loaded first. Later
  requests are fast.
- **`router mode enabled - do not expose to untrusted environments`**: expected. We bind to
  `127.0.0.1` and require a key.
- **Gemma 4 log warnings** (`control-looking token … probably a bug in the model`) are harmless
  metadata quirks.
- **Free disk:** the smoke-test model is 5.2 GB (Q8_0 plus mmproj). Watch disk space before adding
  big models.
