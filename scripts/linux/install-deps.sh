#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: bash install-deps.sh"
  echo "Installs public Ubuntu packages required to build the pinned Inferno backend."
  exit 0
fi
if (($#)); then
  echo "ERROR: unknown argument: $1" >&2
  exit 2
fi
if ! command -v apt-get >/dev/null; then
  echo "ERROR: UNSUPPORTED_DISTRO: this installer requires Ubuntu/Debian apt" >&2
  exit 3
fi
if [[ $EUID -eq 0 ]]; then
  echo "Run this script as your normal WSL user; it invokes sudo for apt." >&2
  exit 2
fi

packages=(
  build-essential libtool meson ninja-build pkg-config device-tree-compiler
  libglib2.0-dev gnutls-bin libpng-dev libslirp-dev libssh-dev libusb-1.0-0-dev
  liblzo2-dev libncurses-dev libpixman-1-dev libsnappy-dev vde2 zstd libzstd-dev
  libgnutls28-dev libgmp-dev liblzfse-dev libgtk-3-dev libsdl2-dev git cmake
  python3 python3-venv curl wget unzip libssl-dev libattr1-dev cloud-image-utils
  xorriso openssh-client xz-utils libjpeg-turbo8-dev
)

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
echo "Inferno build dependencies are installed."
