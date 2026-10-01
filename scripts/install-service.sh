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

# 2. Log folder.
mkdir -p "$HOME/Library/Logs/llm-inference"

# 3. Render the plist with this machine's paths.
sed -e "s#__HOME__#$HOME#g" -e "s#__REPO__#$REPO#g" \
  "$REPO/launchd/llama-server.plist.template" > "$PLIST"
plutil -lint "$PLIST"

# 4. (Re)load the service.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Installed $LABEL. Check with:"
echo "  launchctl print gui/$(id -u)/$LABEL | grep -E 'state|pid'"
echo "  curl -s -H \"Authorization: Bearer \$(head -1 $KEYS)\" http://127.0.0.1:8080/v1/models"
