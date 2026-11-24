#!/usr/bin/env bash
# Setup for Paperclip in Docker. Safe to re-run: secrets are created once and
# never changed; folders, LAN address and resource limits are refreshed.
set -euo pipefail
cd "$(dirname "$0")"

# Set KEY=VALUE in .env (replace if present, append if not)
set_env() {
  local key=$1 val=$2
  if grep -q "^${key}=" .env; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" .env && rm -f .env.bak
  else
    echo "${key}=${val}" >> .env
  fi
}
get_env() { grep "^$1=" .env | head -1 | cut -d= -f2- ; }

# ---------- .env and secrets (only once) ----------
[ -f .env ] || { cp .env.example .env; chmod 600 .env; echo "Created .env"; }
[ -n "$(get_env BETTER_AUTH_SECRET)" ] || set_env BETTER_AUTH_SECRET "$(openssl rand -hex 32)"
[ -n "$(get_env PAPERCLIP_TOOL_ACTION_SIGNING_SECRET)" ] || set_env PAPERCLIP_TOOL_ACTION_SIGNING_SECRET "$(openssl rand -hex 32)"

# ---------- Folders (default ~/<name>; keep any path you already set) ----------
for pair in OBSIDIAN_DIR:obsidian_notes REPOS_DIR:repos MISC_DIR:misc; do
  key=${pair%%:*}; name=${pair#*:}
  dir=$(get_env "$key"); [ -n "$dir" ] || dir="$HOME/$name"
  if [ ! -d "$dir" ]; then
    echo "WARNING: $dir does not exist. Edit $key in .env if it lives elsewhere."
    echo "         (Creating it empty so Docker can start.)"
    mkdir -p "$dir"
  fi
  set_env "$key" "$dir"
done

# ---------- LAN address ----------
if [ "$(uname)" = "Darwin" ]; then
  ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
else
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
[ -n "${ip:-}" ] || ip=localhost
set_env PAPERCLIP_PUBLIC_URL "http://${ip}:3100"

# ---------- Resources: 40% of cores, 20% of memory ----------
if [ "$(uname)" = "Darwin" ]; then
  cores=$(sysctl -n hw.ncpu)
  mem_bytes=$(sysctl -n hw.memsize)
else
  cores=$(nproc)
  mem_bytes=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) * 1024 ))
fi
cpus=$(awk -v c="$cores" 'BEGIN { v=c*0.4; if (v<1) v=1; printf "%.1f", v }')
mem_mb=$(( mem_bytes * 20 / 100 / 1024 / 1024 ))

# Docker Desktop runs in a VM that may have fewer resources than the laptop
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
  read -r d_cpus d_mem < <(docker info --format '{{.NCPU}} {{.MemTotal}}')
  d_mem_mb=$(( d_mem / 1024 / 1024 ))
  if awk -v a="$cpus" -v b="$d_cpus" 'BEGIN{exit !(a>b)}'; then
    echo "NOTE: Docker only has $d_cpus CPUs; capping to that (raise it in Docker Desktop > Resources)."
    cpus=$d_cpus
  fi
  if [ "$mem_mb" -gt "$d_mem_mb" ]; then
    echo "NOTE: Docker only has ${d_mem_mb}MB memory; capping to that (raise it in Docker Desktop > Resources)."
    mem_mb=$d_mem_mb
  fi
fi
set_env PAPERCLIP_CPUS "$cpus"
set_env PAPERCLIP_MEM "${mem_mb}m"

mkdir -p paperclip-data

echo
echo "Laptop: $cores cores, $(( mem_bytes / 1024 / 1024 / 1024 ))GB RAM"
echo "Paperclip limits: $cpus CPUs, ${mem_mb}MB memory"
echo "Folders: $(get_env OBSIDIAN_DIR), $(get_env REPOS_DIR), $(get_env MISC_DIR)"
echo "Open from other devices: $(get_env PAPERCLIP_PUBLIC_URL)"
echo
if [ -z "$(get_env CLAUDE_CODE_OAUTH_TOKEN)" ]; then
  echo "Next: run 'claude setup-token' and paste the token into .env (CLAUDE_CODE_OAUTH_TOKEN)"
fi
echo "Then: docker compose up -d --build"
echo "      docker exec -it -u node paperclip codex login --device-auth   (first time only)"
