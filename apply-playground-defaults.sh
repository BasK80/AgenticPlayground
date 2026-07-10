#!/usr/bin/env bash
# Run this script FROM THE HOST (not inside the dev container) — it copies
# the updated firewall entrypoint into the read-only-mounted
# .devcontainer/firewall directory, then rebuilds and restarts that
# container.
#
# Change: default-on feature-sets now include `copilot`, `pypi`, and
# `golang` (in addition to the existing anthropic/github/npm/opencode),
# matching AgenticPlayground's "convenience for low-risk work" positioning.
# This only affects FRESH /policy volumes (new projects) — your currently
# running project's feature toggles are untouched. To apply it to an
# already-running project instead of/in addition to rebuilding, run:
#   docker exec "$FW" fw feature on copilot
#   docker exec "$FW" fw feature on pypi
#   docker exec "$FW" fw feature on golang
set -euo pipefail
cd "$(dirname "$0")"

echo "Copying updated firewall entrypoint..."
cp .copilot-staging/firewall/entrypoint.sh .devcontainer/firewall/entrypoint.sh
chmod +x .devcontainer/firewall/entrypoint.sh

echo "Rebuilding and restarting the firewall container..."
cd .devcontainer
docker compose build firewall
docker compose up -d firewall

echo
echo "Done. This only affects fresh /policy volumes (new projects)."
echo "Verify with:"
echo '  FW="agentic-$(basename "$(dirname "$PWD")")-firewall"'
echo '  docker exec "$FW" fw feature list'
echo
echo "Once verified, you can remove the staging directory and this script:"
echo "  rm -rf ../.copilot-staging ../apply-playground-defaults.sh"
