# AGENTS.md

## Cursor Cloud specific instructions

### Product overview

Nebbie Arcane is an Italian text-based MUD server. The primary deliverable is the `myst` binary plus world data under `mudroot/lib`. Players connect via Telnet on port **4000** (default). MySQL 8 (`nebbie` database) runs inside the same Docker container as the game server.

See `README.md` for the canonical Docker and Vagrant workflows.

### Services

| Service | Required | How to run |
|---------|----------|------------|
| Docker daemon | Yes | See **Docker daemon** below |
| `nebbieserver` container | Yes | `./docker-run.sh up -d` (after image build) |
| MySQL 8 | Bundled | Started by `docker-entrypoint.sh` inside the container |
| `mudroot/lib` world data | Yes | `./getworldlocal` (repo root `myst.*` files) or `./getworld` (SSH to prod) |

There is no npm/pnpm/Python app server or separate web frontend in this repo.

### Docker daemon

Cloud VMs may not run systemd as PID 1. If `docker ps` fails with a socket permission or connection error:

```bash
sudo dockerd > /tmp/dockerd.log 2>&1 &
```

Use `sudo ./docker-run.sh …` until the `ubuntu` user’s `docker` group membership is active in the shell. After a fresh Docker install, `sudo usermod -aG docker ubuntu` is applied once in the VM snapshot.

### First-time setup

```bash
./getworldlocal          # copy myst.{mob,obj,wld,...} into mudroot/lib
sudo ./docker-run.sh build
sudo ./docker-run.sh up -d
```

The Docker image build compiles `myst` inside Ubuntu 24.04 with GCC 12 and the ODB toolchain (`scripts/install-odb-toolchain.sh`). Expect the first build to take several minutes (network fetch to `pkg.cppget.org` plus full C++ compile).

### Fresh MySQL database caveat

On a **first run** with an empty `./mysql_data` volume, `./docker-run.sh up` can exit because `docker-entrypoint.sh` applies `docs/schema-s1-toon-migration-flags.sql` before ODB has created the `toon` table (`set -e` aborts on the SQL error). MySQL and the `nebbie` database are still initialized under `./mysql_data`.

**Workaround** (start MySQL + `myst` without the failing migration step):

```bash
sudo docker rm -f nebbieserver 2>/dev/null
sudo docker run -d --name nebbieserver \
  --entrypoint bash \
  -v "$PWD/mudroot/lib:/app/mudroot/lib" \
  -v "$PWD/mysql_data:/var/lib/mysql" \
  -p 127.0.0.1:4000:4000 \
  -p 127.0.0.1:4001:4001 \
  -p 127.0.0.1:4002:4002 \
  workspace-nebbieserver \
  -c 'set -e
MYSQL_DATA_DIR="/var/lib/mysql"; MYSQL_RUN_DIR="/var/run/mysqld"
mkdir -p ${MYSQL_RUN_DIR} /var/log/mysql
chown -R mysql:mysql ${MYSQL_DATA_DIR} ${MYSQL_RUN_DIR} /var/log/mysql
rm -f ${MYSQL_RUN_DIR}/mysqld.pid
su -s /bin/bash mysql -c "/usr/sbin/mysqld --bind-address=0.0.0.0 --datadir=${MYSQL_DATA_DIR} --socket=${MYSQL_RUN_DIR}/mysqld.sock --pid-file=${MYSQL_RUN_DIR}/mysqld.pid --log-error=/var/log/mysql/error.log" &
for i in $(seq 1 60); do mysqladmin ping -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -psecret >/dev/null 2>&1 && break; sleep 1; done
exec su -l vagrant -c "cd /app && /app/mudroot/myst -P 4000 -d mudroot/lib"'
```

After ODB creates account tables on first boot, optional S1 DDL can be applied with `./scripts/apply-schema-s1.sh` from inside the container or via `docker exec`.

### Day-to-day commands

| Action | Command |
|--------|---------|
| Start server | `sudo ./docker-run.sh up -d` |
| Stop server | `sudo ./docker-run.sh down` |
| View logs | `sudo docker logs -f nebbieserver` |
| Custom port | `SERVER_PORT=4001 sudo ./docker-run.sh up -d` |
| Rebuild image | `sudo ./docker-run.sh build` |

### Verify the server

```bash
nc -w 3 127.0.0.1 4000    # expect Italian login prompt
sudo docker logs nebbieserver | tail -5   # expect "Entering game loop on port 4000"
```

### Build / lint / tests

| Check | Command | Notes |
|-------|---------|-------|
| **Build (canonical)** | `sudo ./docker-run.sh build` | Full compile inside Docker; matches CI intent |
| **Build (native / Vagrant)** | `./build.sh vagrant` | Requires host ODB toolchain (`scripts/install-odb-toolchain.sh`) |
| **Quick rebuild** | `./quick.sh` | Incremental make after initial CMake build |
| **Style** | `cmake --build build --target style` | Uses bundled `./astyle` (after `build.sh`) |
| **Static analysis** | `cmake --build build --target checkcpp` | Requires `cppcheck` and `cppcheck-htmlreport` |
| **Automated tests** | None in CI | `.travis.yml` only runs `./build.sh` |

There is no unit-test suite; validation is compile + run the Telnet server.

### Alternative: Vagrant

`vagrant up` provisions Ubuntu 24.04 Noble with the same toolchain (`scripts/vagrant-provision-noble.sh`). Requires VirtualBox and is not used in Cloud Agent VMs; prefer Docker here.
