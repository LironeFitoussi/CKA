#!/usr/bin/env bash
# Unified install: containerd + ctr, nerdctl, CNI plugins, buildkit
# Linux amd64 preferred. Run with sudo or as root.
set -euo pipefail

CONTAINERD_VER="2.3.0"
NERDCTL_VER="2.3.4"
CNI_VER="1.9.1"
BUILDKIT_VER="0.31.1"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

WORKDIR="$(mktemp -d)"
cd "$WORKDIR"

echo "==> Installing containerd v${CONTAINERD_VER}"
wget -q "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-${ARCH}.tar.gz"
sudo tar -C /usr/local -xzf "containerd-${CONTAINERD_VER}-linux-${ARCH}.tar.gz"
ctr --version

echo "==> Installing nerdctl v${NERDCTL_VER}"
wget -q "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VER}/nerdctl-${NERDCTL_VER}-linux-${ARCH}.tar.gz"
tar -xzf "nerdctl-${NERDCTL_VER}-linux-${ARCH}.tar.gz" nerdctl
sudo mv nerdctl /usr/local/bin/

echo "==> Installing CNI plugins v${CNI_VER}"
wget -q "https://github.com/containernetworking/plugins/releases/download/v${CNI_VER}/cni-plugins-linux-${ARCH}-v${CNI_VER}.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf "cni-plugins-linux-${ARCH}-v${CNI_VER}.tgz"

echo "==> Installing buildkit v${BUILDKIT_VER} (optional)"
wget -q "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VER}/buildkit-v${BUILDKIT_VER}.linux-${ARCH}.tar.gz"
tar -xzf "buildkit-v${BUILDKIT_VER}.linux-${ARCH}.tar.gz"
sudo mv "buildkit-v${BUILDKIT_VER}.linux-${ARCH}/bin/"* /usr/local/bin/

cd - >/dev/null
rm -rf "$WORKDIR"

echo "==> Done. Versions:"
ctr --version
nerdctl --version
