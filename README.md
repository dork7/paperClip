# Paperclip in Docker (Claude Code + Codex subscriptions)

## Files
- `Dockerfile` – official Paperclip image + git, latest Claude Code & Codex CLIs
- `docker-compose.yml` – LAN-accessible port, data volume, your three folders, CPU/memory limits
- `.env.example` – secrets and tokens template
- `setup.sh` – generates secrets, sets folder paths, LAN address and resource limits (40% cores / 20% RAM). Safe to re-run.

## First run
```bash
./setup.sh
claude setup-token                 # on your laptop; paste result into .env
docker compose up -d --build
docker exec -it -u node paperclip codex login --device-auth
```
Open http://localhost:3100 and claim the instance immediately (first account = admin).
From phone/other devices on the same network: the `PAPERCLIP_PUBLIC_URL` that setup.sh prints.

## Creating agents
- Claude agents: adapter **Claude Local** (`claude_local`), working directory e.g. `/projects/repos/<repo>`, `/projects/obsidian_notes` or `/projects/misc`
- Codex agents: adapter **Codex Local** (`codex_local`), working directory e.g. `/projects/repos/<repo>`, `/projects/obsidian_notes` or `/projects/misc`
- Press **Test Environment** on each before saving. Set a monthly budget per agent.

## What agents can access
Only these, mounted under `/projects`:
- `OBSIDIAN_DIR` -> `/projects/obsidian_notes`
- `REPOS_DIR` -> `/projects/repos`
- `MISC_DIR` -> `/projects/misc`
plus Paperclip's own `paperclip-data/`. Change paths in `.env`, then `docker compose up -d`.
To make a folder read-only, add `:ro` to its line in docker-compose.yml (e.g. `/projects/obsidian_notes:ro`).
Nothing else on your laptop. Keep each project in git so you can review/undo changes.

## Everyday commands
```bash
docker compose logs -f paperclip   # watch logs
docker compose down                # stop
docker compose up -d --build       # update to latest Paperclip/CLIs
```

## Troubleshooting
- **Codex device login fails** – enable device code login in ChatGPT security settings, or run
  `codex login` on your laptop and copy `~/.codex/auth.json` to `paperclip-data/.codex/auth.json`.
- **Claude "not authenticated"** – check `CLAUDE_CODE_OAUTH_TOKEN` in `.env`, then
  `docker compose up -d` to reload. Make sure `ANTHROPIC_API_KEY` is not set.
- **Permission denied on paperclip-data** – `sudo chown -R 1000:1000 paperclip-data` (Linux hosts).

- **Laptop IP changed (new Wi-Fi)** – re-run `./setup.sh`, then `docker compose up -d`.
- **Can't open from another device** – allow port 3100 in your laptop firewall; both devices must be on the same network.

## Backup / move to a VPS
Copy this folder including `paperclip-data/` and `.env`. Never regenerate the secrets.
