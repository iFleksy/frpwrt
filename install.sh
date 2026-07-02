#!/bin/sh
#
# frpc installer for OpenWRT.
# Downloads the frpc binary, installs the UCI config and the procd init script,
# then enables and starts the service.
#
# Run this ON the router (ash-compatible, no bashisms).
#
# Usage:
#   FRP_VERSION=0.69.1 FRP_ARCH=arm64 sh install.sh
#
# Optional token auth (matches the frps server), applied to UCI on install:
#   FRP_TOKEN=my_secret_token sh install.sh
#
# Override any of the variables below via the environment.

set -e

FRP_VERSION="${FRP_VERSION:-0.69.1}"
FRP_ARCH="${FRP_ARCH:-arm64}"
FRP_OS="${FRP_OS:-linux}"
FRP_DOWNLOAD_URL="${FRP_DOWNLOAD_URL:-https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_${FRP_OS}_${FRP_ARCH}.tar.gz}"

# Directory that holds this script + the files/ tree.
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/frp.XXXXXX)"
TARBALL="frp_${FRP_VERSION}_${FRP_OS}_${FRP_ARCH}.tar.gz"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

# install_file <mode> <src> <dst> — BusyBox has no `install` applet, so do it by hand.
install_file() {
	mode="$1"; src="$2"; dst="$3"
	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
	chmod "$mode" "$dst"
}

echo ">> Downloading frpc ${FRP_VERSION} (${FRP_OS}/${FRP_ARCH})"
echo "   $FRP_DOWNLOAD_URL"

# BusyBox wget may lack TLS; fall back to curl / uclient-fetch if present.
if wget -q "$FRP_DOWNLOAD_URL" -O "$TMP_DIR/$TARBALL" 2>/dev/null; then
	:
elif command -v curl >/dev/null 2>&1; then
	curl -fsSL "$FRP_DOWNLOAD_URL" -o "$TMP_DIR/$TARBALL"
elif command -v uclient-fetch >/dev/null 2>&1; then
	uclient-fetch -q "$FRP_DOWNLOAD_URL" -O "$TMP_DIR/$TARBALL"
else
	echo "!! Could not download. Install ca-bundle/wget-ssl or curl and retry." >&2
	exit 1
fi

echo ">> Extracting frpc binary"
tar -xzf "$TMP_DIR/$TARBALL" -C "$TMP_DIR"
EXTRACT_DIR="$TMP_DIR/frp_${FRP_VERSION}_${FRP_OS}_${FRP_ARCH}"

echo ">> Installing frpc binary to /usr/bin/frpc"
install_file 0755 "$EXTRACT_DIR/frpc" /usr/bin/frpc

echo ">> Installing init script to /etc/init.d/frpc"
install_file 0755 "$SRC_DIR/files/etc/init.d/frpc" /etc/init.d/frpc

if [ -f /etc/config/frpc ]; then
	echo ">> Keeping existing /etc/config/frpc (not overwriting)"
else
	echo ">> Installing default UCI config to /etc/config/frpc"
	install_file 0600 "$SRC_DIR/files/etc/config/frpc" /etc/config/frpc
	echo "   Edit it with: uci show frpc  /  vi /etc/config/frpc"
fi

# Optional token auth: set only when FRP_TOKEN is provided.
if [ -n "${FRP_TOKEN:-}" ]; then
	echo ">> Setting auth token from \$FRP_TOKEN"
	uci set frpc.common.auth_token="$FRP_TOKEN"
	uci commit frpc
fi

echo ">> Enabling and (re)starting the frpc service"
/etc/init.d/frpc enable
/etc/init.d/frpc restart

echo ""
echo "Done. frpc ${FRP_VERSION} installed."
echo "  Config : /etc/config/frpc"
echo "  Control: /etc/init.d/frpc {start|stop|restart|reload|enable|disable}"
echo "  Logs   : logread -e frpc   and   /var/log/frpc.log"
