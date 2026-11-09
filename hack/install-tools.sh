#!/usr/bin/env bash
# Install pinned validation tools into .bin and .venv.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${BIN_DIR:-$ROOT/.bin}"
VENV="${VENV_DIR:-$ROOT/.venv}"

KUBECONFORM_VERSION="${KUBECONFORM_VERSION:-v0.8.0}"
KUBE_LINTER_VERSION="${KUBE_LINTER_VERSION:-0.8.3}"
YAMLLINT_VERSION="${YAMLLINT_VERSION:-1.38.0}"
GITLEAKS_VERSION="${GITLEAKS_VERSION:-8.30.1}"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  x86_64 | amd64) arch="amd64" ;;
  aarch64 | arm64) arch="arm64" ;;
  *)
    echo "unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

mkdir -p "$BIN"

fetch_tar() {
  local url="$1" member="$2" dest="$3" tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/archive.tar.gz"
  tar -xzf "$tmp/archive.tar.gz" -C "$tmp" "$member"
  install -m 0755 "$tmp/$member" "$dest"
  rm -rf "$tmp"
}

if [ ! -x "$BIN/kubeconform" ]; then
  echo "installing kubeconform $KUBECONFORM_VERSION"
  fetch_tar \
    "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-${os}-${arch}.tar.gz" \
    kubeconform \
    "$BIN/kubeconform"
fi

if [ ! -x "$BIN/kube-linter" ]; then
  case "$os-$arch" in
    linux-amd64) asset="kube-linter-linux.tar.gz" ;;
    linux-arm64) asset="kube-linter-linux_arm64.tar.gz" ;;
    darwin-amd64) asset="kube-linter-darwin.tar.gz" ;;
    darwin-arm64) asset="kube-linter-darwin_arm64.tar.gz" ;;
    *)
      echo "no kube-linter build for $os-$arch" >&2
      exit 1
      ;;
  esac
  echo "installing kube-linter $KUBE_LINTER_VERSION"
  fetch_tar \
    "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/${asset}" \
    kube-linter \
    "$BIN/kube-linter"
fi

if [ ! -x "$BIN/gitleaks" ]; then
  case "$os-$arch" in
    linux-amd64) asset="gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" ;;
    linux-arm64) asset="gitleaks_${GITLEAKS_VERSION}_linux_arm64.tar.gz" ;;
    darwin-amd64) asset="gitleaks_${GITLEAKS_VERSION}_darwin_x64.tar.gz" ;;
    darwin-arm64) asset="gitleaks_${GITLEAKS_VERSION}_darwin_arm64.tar.gz" ;;
    *)
      echo "no gitleaks build for $os-$arch" >&2
      exit 1
      ;;
  esac
  echo "installing gitleaks $GITLEAKS_VERSION"
  fetch_tar \
    "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${asset}" \
    gitleaks \
    "$BIN/gitleaks"
fi

if [ ! -x "$VENV/bin/yamllint" ]; then
  echo "installing yamllint $YAMLLINT_VERSION"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check "yamllint==${YAMLLINT_VERSION}"
fi

echo "tools ready in $BIN and $VENV"
