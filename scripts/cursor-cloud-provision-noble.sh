#!/bin/bash
# Provisioning Cursor Cloud — allineato a scripts/vagrant-provision-noble.sh
# (Ubuntu 24.04 Noble, GCC 12, ODB 2.5 via build2/bpkg, MySQL 8 root/secret/nebbie).
# Idempotente: sicuro da rilanciare.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

CLOUD_USER="${CLOUD_USER:-ubuntu}"
WORKSPACE="${WORKSPACE:-/workspace}"
MARKER_DIR=/var/lib/nebbie
ODB_MARKER="${MARKER_DIR}/odb-toolchain-installed"
ODB_BUILD=/var/cache/nebbie-odb-build
APT_MARKER="${MARKER_DIR}/apt-base-installed"
LOG_FILE=/var/log/nebbie-cursor-cloud-provision.log

mkdir -p "$MARKER_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> Cursor Cloud provision (user=${CLOUD_USER}, workspace=${WORKSPACE})"

ensure_dns() {
	if getent hosts pkg.cppget.org >/dev/null 2>&1 \
		&& getent hosts archive.ubuntu.com >/dev/null 2>&1; then
		echo "==> DNS OK"
		return 0
	fi
	echo "==> Riparo DNS (8.8.8.8 / 1.1.1.1)"
	if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
		install -d -m 0755 /etc/systemd/resolved.conf.d
		cat >/etc/systemd/resolved.conf.d/10-nebbie-dns.conf <<'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=8.8.4.4
EOF
		systemctl restart systemd-resolved 2>/dev/null || true
	else
		if [ -f /etc/resolv.conf ] && ! grep -qE '^nameserver (8\.8\.8\.8|1\.1\.1\.1)' /etc/resolv.conf; then
			printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' >>/etc/resolv.conf
		fi
	fi
	sleep 2
	getent hosts pkg.cppget.org >/dev/null 2>&1
}

odb_already_installed() {
	command -v odb >/dev/null 2>&1 \
		&& odb --version 2>&1 | grep -q '2\.5' \
		&& ldconfig -p 2>/dev/null | grep -q 'libodb-mysql.so' \
		&& [ -f /etc/ld.so.conf.d/odb-local.conf ]
}

purge_apt_odb() {
	echo "==> Rimuovo eventuali pacchetti ODB 2.4 da apt (usiamo ODB 2.5 build2)"
	apt-get -qq remove -y \
		odb libodb-dev libodb-mysql-dev libodb-sqlite-dev libodb-boost-dev \
		2>/dev/null || true
	apt-get -qq autoremove -y 2>/dev/null || true
}

install_odb_toolchain() {
	echo "==> ODB 2.5 (build2 + bpkg, scripts/install-odb-toolchain.sh)"
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	export ODB_BUILD

	if ! swapon --show | grep -q '/swapfile'; then
		echo "==> Swap temporaneo 8G per build ODB (opzionale in Cloud VM)"
		if fallocate -l 8G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=8192 status=none; then
			chmod 600 /swapfile
			if mkswap /swapfile && swapon /swapfile; then
				SWAP_CREATED=1
			else
				echo "==> Swap non disponibile in questo ambiente, continuo senza swap"
				rm -f /swapfile
			fi
		fi
	fi

	bash "${SCRIPT_DIR}/install-odb-toolchain.sh"
	touch "$ODB_MARKER"

	if [ "${SWAP_CREATED:-0}" = "1" ]; then
		swapoff /swapfile || true
		rm -f /swapfile
	fi
}

set_gcc12_default() {
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 100
	update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 100
	update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-12 100
	update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-12 100
	update-alternatives --set gcc /usr/bin/gcc-12
	update-alternatives --set g++ /usr/bin/g++-12
	update-alternatives --set cc /usr/bin/gcc-12
	update-alternatives --set c++ /usr/bin/g++-12
}

start_mysql() {
	MYSQL_DATA_DIR="/var/lib/mysql"
	MYSQL_RUN_DIR="/var/run/mysqld"
	MYSQL_PASSWORD="secret"
	MYSQL_DB="nebbie"

	if mysqladmin ping -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; then
		echo "==> MySQL già in esecuzione"
		return 0
	fi

	mkdir -p "${MYSQL_RUN_DIR}" /var/log/mysql
	chown -R mysql:mysql "${MYSQL_DATA_DIR}" "${MYSQL_RUN_DIR}" /var/log/mysql 2>/dev/null || true
	rm -f "${MYSQL_RUN_DIR}/mysqld.pid"

	if [ ! -d "${MYSQL_DATA_DIR}/mysql" ]; then
		echo "==> Inizializzo datadir MySQL"
		su -s /bin/bash mysql -c "/usr/sbin/mysqld --initialize-insecure --user=mysql --datadir=${MYSQL_DATA_DIR}"
	fi

	if command -v systemctl >/dev/null 2>&1 \
		&& [ -d /run/systemd/system ] \
		&& systemctl is-system-running >/dev/null 2>&1; then
		systemctl enable mysql 2>/dev/null || true
		systemctl start mysql 2>/dev/null || true
	else
		echo "==> Avvio MySQL senza systemd"
		su -s /bin/bash mysql -c "/usr/sbin/mysqld --bind-address=127.0.0.1 --datadir=${MYSQL_DATA_DIR} --socket=${MYSQL_RUN_DIR}/mysqld.sock --pid-file=${MYSQL_RUN_DIR}/mysqld.pid --log-error=/var/log/mysql/error.log" &
	fi

	for i in $(seq 1 60); do
		if mysqladmin ping -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; then
			break
		fi
		if mysqladmin ping -h 127.0.0.1 -P 3306 --protocol=TCP -uroot --silent 2>/dev/null; then
			mysql -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';" 2>/dev/null || true
			break
		fi
		sleep 1
	done

	mysqladmin ping -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -p"${MYSQL_PASSWORD}" --silent

	mysql -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -p"${MYSQL_PASSWORD}" \
		-e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DB};" 2>/dev/null \
		|| mysql -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DB};"

	MIGRATION_FLAGS="${WORKSPACE}/docs/schema-s1-toon-migration-flags.sql"
	if [ -f "$MIGRATION_FLAGS" ]; then
		HAS_TOON=$(mysql -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -p"${MYSQL_PASSWORD}" -N -e \
			"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DB}' AND TABLE_NAME='toon';" 2>/dev/null || echo "0")
		if [ "$HAS_TOON" != "0" ]; then
			HAS_COL=$(mysql -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -p"${MYSQL_PASSWORD}" -N -e \
				"SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='${MYSQL_DB}' AND TABLE_NAME='toon' AND COLUMN_NAME='migrated_at';" 2>/dev/null || echo "0")
			if [ "$HAS_COL" = "0" ]; then
				echo "==> Applico DDL cutover toon (migrated_at)"
				mysql -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -p"${MYSQL_PASSWORD}" "${MYSQL_DB}" <"$MIGRATION_FLAGS" \
					|| mysql -h 127.0.0.1 -P 3306 --protocol=TCP -uroot "${MYSQL_DB}" <"$MIGRATION_FLAGS"
			fi
		fi
	fi
}

ensure_dns
purge_apt_odb

echo "==> apt update"
apt-get -qq update || true

if [ ! -f "$APT_MARKER" ]; then
	echo "==> MySQL debconf (password secret)"
	echo "mysql-server mysql-server/root_password password secret" | debconf-set-selections
	echo "mysql-server mysql-server/root_password_again password secret" | debconf-set-selections

	echo "==> Dipendenze (stesso set di vagrant-provision-noble.sh / Dockerfile)"
	apt-get -qq install -y \
		git php8.3-cli gcc-12 g++-12 gcc-12-plugin-dev apache2 make cmake \
		libconfig++-dev lnav libsqlite3-dev libcurlpp-dev gdb wget curl ca-certificates \
		libcurl4-openssl-dev \
		libboost-dev libboost-program-options-dev libboost-system-dev \
		libboost-filesystem-dev liblog4cxx-dev libboost-date-time-dev \
		librtmp-dev libnghttp2-dev libkrb5-dev comerr-dev libpsl-dev libssh-dev libbrotli-dev \
		mysql-server mysql-client libmysqlclient-dev libmysqlcppconn-dev \
		net-tools iproute2 vim less dos2unix build-essential sudo
	touch "$APT_MARKER"
else
	echo "==> Dipendenze già installate (rm ${APT_MARKER} per reinstallare)"
fi

set_gcc12_default

if [ -f "$ODB_MARKER" ] && odb_already_installed; then
	echo "==> ODB 2.5 già installato (rm ${ODB_MARKER} per rebuild)"
else
	install_odb_toolchain
fi

purge_apt_odb

echo "==> Git config ${CLOUD_USER}"
sudo -iu "$CLOUD_USER" git config --global user.email "nebbie@hexkeep.com"
sudo -iu "$CLOUD_USER" git config --global user.name "Nebbie Server"

echo "==> Confs/vagrant.conf"
install -d -o "$CLOUD_USER" -g "$CLOUD_USER" "/home/${CLOUD_USER}/Confs"
cat >"/home/${CLOUD_USER}/Confs/vagrant.conf" <<'EOF'
MYSQL_USER="root" #db user
MYSQL_PASSWORD="secret" # db password
MYSQL_HOST="localhost" #db host
MYSQL_DB="nebbie" #db name
SERVER_PORT=4000 #default server port
EOF
chown "${CLOUD_USER}:${CLOUD_USER}" "/home/${CLOUD_USER}/Confs/vagrant.conf"

echo "==> MySQL + database nebbie"
start_mysql

if [ -x "${WORKSPACE}/scripts/link-dev-toons-to-account.sh" ]; then
	echo "==> Setup PG dev Sirio -> wizmorgan@gmail.com (se presente)"
	bash "${WORKSPACE}/scripts/link-dev-toons-to-account.sh" --boost || true
fi

echo "==> World data"
if [ -x "${WORKSPACE}/getworldlocal" ]; then
	sudo -iu "$CLOUD_USER" "${WORKSPACE}/getworldlocal"
fi

echo "==> Build myst (${WORKSPACE}/build.sh vagrant)"
sudo -iu "$CLOUD_USER" bash -lc "cd '${WORKSPACE}' && ./build.sh vagrant"

echo "==> Verifica toolchain"
echo "gcc:  $(gcc --version | head -1)"
echo "g++:  $(g++ --version | head -1)"
echo "cc:   $(readlink -f "$(command -v cc)" 2>/dev/null || command -v cc)"
echo "c++:  $(readlink -f "$(command -v c++)" 2>/dev/null || command -v c++)"
echo "odb:  $(odb --version 2>&1 | head -1)"
mysql -h 127.0.0.1 -P 3306 --protocol=TCP -uroot -psecret -e "SHOW DATABASES LIKE 'nebbie';"

if [ -x "${WORKSPACE}/mudroot/myst" ]; then
	echo "==> myst: ${WORKSPACE}/mudroot/myst"
else
	echo "ERRORE: myst non trovato dopo build"
	exit 1
fi

echo "==> Cursor Cloud provision completato"
