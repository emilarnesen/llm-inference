#!/bin/sh
# Stop and remove the llama-server launchd agent. Keeps models, logs and the API key.
set -eu
LABEL="local.llm-inference.llama-server"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
echo "Removed $LABEL."
