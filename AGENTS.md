# AGENTS.md

Guidance for AI agents working in this repository.

## Cursor Cloud specific instructions

### Product overview

Nebbie Arcane is a C++17 MUD (text-based multiplayer game) server. Players connect via telnet/MUD client to port **4000**. MySQL 8 stores account data; game world files live under `mudroot/lib/`.

### Recommended dev path: Docker

Docker bundles MySQL, the ODB toolchain, and the compiled `myst` binary (see `README.md` → Docker section). Native/Vagrant builds are possible but slow to provision (ODB via build2).

**One-time VM setup (not in the update script):** Docker CE with `fuse-overlayfs` storage driver and `iptables-legacy`. Start the daemon if it is not running:

```bash
sudo dockerd > /tmp/dockerd.log 2>&1 &
```

Use `sudo` for `docker` / `./docker-run.sh` unless the user is in the `docker` group.

### Standard commands

| Task | Command |
|------|---------|
| Copy bundled world files into `mudroot/lib` | `./getworldlocal` |
| Build image (first time ~7 min) | `sudo ./docker-run.sh build` |
| Start server (background) | `sudo ./docker-run.sh up -d` |
| Stop server | `sudo ./docker-run.sh down` |
| View logs | `sudo docker logs -f nebbieserver` |
| Connect to game | `telnet 127.0.0.1 4000` |
| Compile-only (CI-style) | `./build.sh` (needs full native deps + ODB; prefer Docker build) |

MySQL credentials (inside container): `root` / `secret`, database `nebbie` (`Confs/vagrant.conf`).

### Fresh MySQL first-run caveat

On a **brand-new** `mysql_data/` directory, `docker-entrypoint.sh` may exit before starting `myst` because it tries to `ALTER TABLE toon` before ODB creates that table (`scripts/apply-schema-s1.sh` skips this case; entrypoint does not).

**Workaround:** mount a patched entrypoint that only applies migration flags when the `toon` table exists:

```bash
cp docker-entrypoint.sh /tmp/docker-entrypoint-patched.sh
# Add HAS_TOON_TABLE check before the HAS_MIGRATED_AT block (same logic as apply-schema-s1.sh)
chmod +x /tmp/docker-entrypoint-patched.sh
sudo docker rm -f nebbieserver 2>/dev/null
sudo docker run -d --name nebbieserver --platform linux/amd64 \
  -v "$PWD/mudroot/lib:/app/mudroot/lib" \
  -v "$PWD/mysql_data:/var/lib/mysql" \
  -v /tmp/docker-entrypoint-patched.sh:/usr/local/bin/docker-entrypoint.sh:ro \
  -p 127.0.0.1:4000:4000 -p 127.0.0.1:4001:4001 -p 127.0.0.1:4002:4002 \
  -e SERVER_PORT=4000 \
  workspace-nebbieserver
```

After `myst` has run once, ODB creates the account schema; `./docker-run.sh up -d` works on subsequent starts if migration flags were skipped on first boot.

### Lint / tests

No dedicated lint or unit-test target in CI. `.travis.yml` only runs `./build.sh` (compile). Gameplay verification is manual via telnet. Gate scripts under `scripts/` (e.g. `gate-sql.sh`, `check-gate-7.7.sh`) require a running server and migrated characters.

### Key paths

- `src/` — all server C++ sources (compiled into `myst`)
- `mudroot/lib/` — runtime world/player data (populate via `./getworldlocal` or `./getworld` for production data)
- `pages/` — in-game text (login banner, help)
- `docker-entrypoint.sh` — starts MySQL then `myst` inside the container
