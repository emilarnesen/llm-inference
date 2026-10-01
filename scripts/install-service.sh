#!/bin/sh
# Install (or reinstall) llama-server as a launchd user agent.
# Safe to re-run: it reloads the service with the current plist template.
set -eu

LABEL="local.llm-inference.llama-server"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
KEYS="$HOME/.config/llm-inference/api-keys"

# 1. API key file (created once, never committed).
if [ ! -f "$KEYS" ]; then
  mkdir -p "$(dirname "$KEYS")"
  umask 077
  openssl rand -hex 32 > "$KEYS"
  echo "Created API key in $KEYS"
fi
chmod 600 "$KEYS"

# 2. Web UI files for the installed llama.cpp build (missing from the Homebrew bottle,
#    see homebrew-core#314191). Re-run this script after `brew upgrade llama.cpp`.
BUILD="$(llama-server --version 2>&1 | sed -n 's/.*(build \([0-9]*\).*/\1/p')"
UI="$HOME/.local/share/llm-inference/ui/b$BUILD"
if [ ! -f "$UI/index.html" ]; then
  TMP="$(mktemp -d)"
  curl -fsSL "https://github.com/ggml-org/llama.cpp/releases/download/b$BUILD/llama-b$BUILD-ui.tar.gz" | tar -xz -C "$TMP"
  mkdir -p "$(dirname "$UI")"
  mv "$(dirname "$(find "$TMP" -name index.html | head -1)")" "$UI"
  rm -rf "$TMP"
  echo "Downloaded web UI for build b$BUILD to $UI"
fi

# 3. Log folder.
mkdir -p "$HOME/Library/Logs/llm-inference"

# 4. Render the plist with this machine's paths.
sed -e "s#__HOME__#$HOME#g" -e "s#__REPO__#$REPO#g" -e "s#__UI__#$UI#g" \
  "$REPO/launchd/llama-server.plist.template" > "$PLIST"
plutil -lint "$PLIST"

# 5. (Re)load the service.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
# bootout returns before the old job is gone; bootstrapping too early fails with
# "Bootstrap failed: 5: Input/output error". Wait up to 10 s for it to disappear.
i=0
while launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1 && [ $i -lt 20 ]; do
  sleep 0.5; i=$((i + 1))
done
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Installed $LABEL. Check with:"
echo "  launchctl print gui/$(id -u)/$LABEL | grep -E 'state|pid'"
echo "  curl -s -H \"Authorization: Bearer \$(head -1 $KEYS)\" http://127.0.0.1:8080/v1/models"
