#!/usr/bin/env bash
# Validate the repository without needing a Kubernetes cluster.
#
# Layers:
#   1. YAML syntax and style (yamllint)
#   2. Every kustomization renders (kubectl kustomize)
#   3. Helm-based Argo Applications render (helm template)
#   4. Kubernetes schema validation (kubeconform + CRD schemas)
#   5. Structural policy checks (kube-linter)
#
# Usage: ./hack/validate.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BIN="${BIN_DIR:-$ROOT/.bin}"
VENV="${VENV_DIR:-$ROOT/.venv}"
PATH="$BIN:$VENV/bin:$PATH"
export PATH

KUBECTL="${KUBECTL:-kubectl}"
KUBECONFORM="${KUBECONFORM:-kubeconform}"
YAMLLINT="${YAMLLINT:-yamllint}"
KUBE_LINTER="${KUBE_LINTER:-kube-linter}"
KUBE_VERSION="${KUBE_VERSION:-1.33.0}"
RENDER_HELM="${RENDER_HELM:-$ROOT/hack/render-helm.sh}"

CRD_SCHEMA='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

fail=0

step() { printf '\n==> %s\n' "$*"; }

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: '$1' not found. Run 'make tools' first." >&2
    exit 2
  fi
}

need "$KUBECTL"
need "$KUBECONFORM"
need "$YAMLLINT"
need "$KUBE_LINTER"

if ! command -v helm >/dev/null 2>&1; then
  echo "error: 'helm' not found. Install Helm 3 before running validation." >&2
  exit 2
fi

tmp="$ROOT/.tmp/validate"
rm -rf "$tmp"
mkdir -p "$tmp/build"
helm_out="$tmp/helm"

# Tracked + non-ignored, untracked YAML only. Ignored local secrets are skipped.
mapfile -t yaml_files < <(
  {
    git ls-files '*.yaml'
    git ls-files --others --exclude-standard '*.yaml'
  } | sort -u
)

step "YAML syntax (yamllint)"
if [ "${#yaml_files[@]}" -eq 0 ]; then
  echo "no YAML files found"
else
  if ! "$YAMLLINT" -f parsable "${yaml_files[@]}"; then
    fail=1
  fi
fi

step "Kustomize builds"
built=()
while IFS= read -r kfile; do
  dir="$(dirname "$kfile")"
  out="$tmp/build/${dir//\//__}.yaml"
  if "$KUBECTL" kustomize "$dir" > "$out" 2> "$out.err"; then
    if [ -s "$out" ]; then
      built+=("$out")
      printf 'ok   %s\n' "$dir"
    else
      printf 'FAIL %s (empty output)\n' "$dir"
      fail=1
    fi
  else
    printf 'FAIL %s\n' "$dir"
    sed 's/^/     /' "$out.err"
    fail=1
  fi
done < <(find applications -name kustomization.yaml -type f | sort)

step "Helm chart rendering"
if ! "$RENDER_HELM" --output "$helm_out"; then
  fail=1
fi

helm_built=()
if [ -d "$helm_out" ]; then
  while IFS= read -r f; do
    helm_built+=("$f")
  done < <(find "$helm_out" -maxdepth 1 -name '*.yaml' -type f | sort)
fi

step "Schema validation (Kubernetes $KUBE_VERSION, Helm-rendered manifests)"
if [ "${#helm_built[@]}" -eq 0 ]; then
  echo "no Helm-rendered manifests to validate"
else
  # CRDs are skipped because the Kubernetes JSON schema catalog does not
  # publish a schema for the CustomResourceDefinition kind itself.
  if ! "$KUBECONFORM" -strict -summary -kubernetes-version "$KUBE_VERSION" \
      -schema-location default \
      -schema-location "$CRD_SCHEMA" \
      -skip CustomResourceDefinition \
      -output text "${helm_built[@]}"; then
    fail=1
  fi
fi

step "Schema validation (Kubernetes $KUBE_VERSION, rendered manifests)"
if [ "${#built[@]}" -eq 0 ]; then
  echo "no rendered manifests to validate"
  fail=1
else
  if ! "$KUBECONFORM" -strict -summary -kubernetes-version "$KUBE_VERSION" \
      -schema-location default \
      -schema-location "$CRD_SCHEMA" \
      -output text "${built[@]}"; then
    fail=1
  fi
fi

step "Schema validation (standalone manifests)"
raw=()
for f in "${yaml_files[@]}"; do
  case "$f" in
    applications/*) ;;
    *) continue ;;
  esac
  case "$f" in
    */kustomization.yaml | */values.yaml) continue ;;
  esac
  raw+=("$f")
done
if [ "${#raw[@]}" -eq 0 ]; then
  echo "no standalone manifests found"
else
  if ! "$KUBECONFORM" -strict -summary -kubernetes-version "$KUBE_VERSION" \
      -schema-location default \
      -schema-location "$CRD_SCHEMA" \
      -output text "${raw[@]}"; then
    fail=1
  fi
fi

step "Structural checks (kube-linter, kustomize)"
if ! "$KUBE_LINTER" lint "$tmp/build" --config .kube-linter.yaml; then
  fail=1
fi

step "Structural checks (kube-linter, Helm-rendered)"
if [ "${#helm_built[@]}" -eq 0 ]; then
  echo "no Helm-rendered manifests to lint"
else
  if ! "$KUBE_LINTER" lint "$helm_out" --config .kube-linter.yaml; then
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  printf '\nValidation failed.\n' >&2
  exit 1
fi

printf '\nAll validations passed.\n'
