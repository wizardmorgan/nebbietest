# Agent Instructions

## Cursor Cloud specific instructions

Do not use Docker for Cursor Cloud environment setup. Configure the Cursor Cloud
machine directly.

This repository uses Vagrant locally, but Cursor Cloud cannot run VirtualBox.
Reproduce `scripts/vagrant-provision-noble.sh` directly on Ubuntu 24.04:

- install `gcc-12`, `g++-12`, `gcc-12-plugin-dev`, and set `gcc`, `g++`, `cc`,
  and `c++` to GCC 12;
- install MySQL server/client packages, set the MySQL `root` password to
  `secret`, and create the `nebbie` database;
- install the Boost, log4cxx, curlpp, libconfig++, sqlite, MySQL, and other
  development packages listed in `scripts/vagrant-provision-noble.sh`;
- install ODB 2.5 using `scripts/install-odb-toolchain.sh`;
- do not install the apt ODB 2.4 packages (`libodb-dev`, `libodb-boost-dev`,
  `libodb-mysql-dev`, `libodb-sqlite-dev`, or their runtime packages), because
  mixing ODB 2.4 runtime libraries with generated ODB 2.5 code can corrupt the
  server at startup;
- create `$HOME/Confs/vagrant.conf` with the same MySQL settings used by
  `scripts/vagrant-provision-noble.sh`;
- verify the setup with `./build.sh vagrant`;
- verify runtime startup with `cd mudroot && ./myst 4000 -N`.

