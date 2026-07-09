# AGENTS.md

## Cursor Cloud specific instructions

### Product overview

Nebbie Arcane is an Italian text-based MUD server. The primary deliverable is the **`myst`** binary plus world data under `mudroot/lib`. Players connect via Telnet on port **4000** (default). MySQL 8 stores accounts in the **`nebbie`** database (`root` / `secret`).

See `README.md` for canonical Docker and Vagrant workflows.

### Recommended: native toolchain (Vagrant-equivalent)

Cursor Cloud VMs should be provisioned like **`scripts/vagrant-provision-noble.sh`** (Ubuntu 24.04 Noble):

| Component | Expected version / config |
|-----------|---------------------------|
| **GCC/G++/cc/c++** | **12** (default via `update-alternatives`, not Clang) |
| **ODB** | **2.5.0** via `scripts/install-odb-toolchain.sh` (build2/bpkg → `/usr/local`) |
| **MySQL** | 8.x, `root` / `secret`, database **`nebbie`** |
| **Libs** | Boost, log4cxx, curlpp, libconfig++, sqlite (apt dev packages) |

**Do not install apt ODB 2.4 packages** (`odb`, `libodb-dev`, …). The provision script removes them if present.

#### One-time / full reprovision

```bash
sudo bash scripts/cursor-cloud-provision-noble.sh
```

Idempotent markers under `/var/lib/nebbie/` (`apt-base-installed`, `odb-toolchain-installed`). Log: `/var/log/nebbie-cursor-cloud-provision.log`.

This script mirrors Vagrant/Docker: apt deps → GCC 12 as default (including `cc`/`c++`) → ODB 2.5 build → `~/Confs/vagrant.conf` → MySQL + `nebbie` → `./getworldlocal` → `./build.sh vagrant`.

First ODB build can take **10–20 minutes** (fetch from `pkg.cppget.org`). Swap is attempted but skipped if unavailable in the VM.

#### Day-to-day (native)

```bash
./getworldlocal                    # refresh mudroot/lib from repo myst.*
./build.sh vagrant                 # rebuild myst (or ./quick.sh after first build)
# Start MySQL if not running (see below)
cd mudroot && ./myst -P 4000 -d lib
```

**MySQL without systemd** (common in Cloud VMs):

```bash
sudo bash -c 'MYSQL_RUN_DIR=/var/run/mysqld; mkdir -p $MYSQL_RUN_DIR /var/log/mysql; chown -R mysql:mysql /var/lib/mysql $MYSQL_RUN_DIR; rm -f $MYSQL_RUN_DIR/mysqld.pid; su -s /bin/bash mysql -c "/usr/sbin/mysqld --bind-address=127.0.0.1 --datadir=/var/lib/mysql --socket=$MYSQL_RUN_DIR/mysqld.sock --pid-file=$MYSQL_RUN_DIR/mysqld.pid --log-error=/var/log/mysql/error.log" &'
sleep 3
mysqladmin ping -h 127.0.0.1 -uroot -psecret
```

Runtime config: `~/Confs/vagrant.conf` (created by provision script).

#### Verify native setup

```bash
gcc --version    # 12.x
cc --version     # must be gcc-12, not clang
odb --version    # ODB compiler ... 2.5.0
mysql -h 127.0.0.1 -uroot -psecret -e "SHOW DATABASES LIKE 'nebbie';"
test -x mudroot/myst && nc -w 3 127.0.0.1 4000   # Italian login prompt
```

### Optional: Docker workflow

Docker bundles the same toolchain inside `nebbieserver`. Useful for parity testing but **not required** when the native stack is provisioned.

```bash
sudo dockerd > /tmp/dockerd.log 2>&1 &    # if docker daemon not running
./getworldlocal
sudo ./docker-run.sh build
sudo ./docker-run.sh up -d
```

**Fresh MySQL volume caveat:** `./docker-run.sh up` can exit on first run when `docker-entrypoint.sh` applies `docs/schema-s1-toon-migration-flags.sql` before the `toon` table exists. Prefer native MySQL + `./myst` on Cloud VMs, or use the custom entrypoint workaround documented in git history / prior PR notes.

### Build / lint / tests

| Check | Command | Notes |
|-------|---------|-------|
| **Build (native)** | `./build.sh vagrant` | Primary after Cloud provision |
| **Build (Docker)** | `sudo ./docker-run.sh build` | Full compile inside container |
| **Quick rebuild** | `./quick.sh` | Incremental make after initial CMake build |
| **Style** | `cmake --build build --target style` | Bundled `./astyle` |
| **Static analysis** | `cmake --build build --target checkcpp` | Requires `cppcheck` |
| **Automated tests** | None | `.travis.yml` only runs `./build.sh` |

### VM update script (session startup)

Runs `./getworldlocal` only. System packages and ODB are installed once via `scripts/cursor-cloud-provision-noble.sh` (VM snapshot), not on every agent session.

### Gotchas

- **`cc`/`c++` → Clang**: Cloud images may default to LLVM. Provision script forces `gcc-12`/`g++-12` for all four commands; CMake fails with `cannot find -lstdc++` if `c++` is still Clang.
- **Port 4000 conflict**: Stop Docker `nebbieserver` before running native `./myst`.
- **S1 DDL**: `./scripts/apply-schema-s1.sh` after ODB creates `toon`; entrypoint skips migration when `toon` is absent (native provision matches Vagrant).
