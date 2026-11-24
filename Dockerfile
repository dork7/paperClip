# Paperclip – local Docker build
# Extends the official image (which already includes Claude Code + Codex CLIs).
FROM ghcr.io/paperclipai/paperclip:latest

# Tools agents commonly need when working on your projects
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 # Refresh the agent CLIs to their latest versions at build time
 && npm install -g @anthropic-ai/claude-code@latest @openai/codex@latest \
 && npm cache clean --force

# Mounted project folders are owned by your laptop user; let git work in them
RUN git config --system --add safe.directory '*'

# Health check so `docker ps` shows whether the server is up
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://localhost:3100/ >/dev/null || exit 1

# Entrypoint, CMD, HOME=/paperclip and port 3100 are inherited from the base image
