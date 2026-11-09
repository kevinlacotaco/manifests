#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${CI:-}" ]]; then
  echo "Refusing to print secrets in CI." >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage:
  hack/get-secret.sh --list
  hack/get-secret.sh <app> [secret] [key]
  DRY_RUN=1 hack/get-secret.sh <app> [secret] [key]

Examples:
  hack/get-secret.sh mealie
  hack/get-secret.sh postgres postgres-secret postgres-password
  DRY_RUN=1 hack/get-secret.sh grafana

The helper only reads the current kubeconfig context and only allows the
app/secret mappings below. It never writes secrets to disk.

Sensitive output. Do not pipe it to files, logs, chat, or CI.
EOF
}

list_apps() {
  cat <<'EOF'
mealie            mealie/mealie-db
donetick          donetick/donetick-secret
postgres          database/postgres-secret, database/postgres-app-secrets
grafana           monitoring/grafana-admin-credentials
alertmanager-ntfy monitoring/alertmanager-ntfy
speedtest         speedtest-tracker/speedtest-tracker-secrets
adguard           networking/adguard-secret
rabbitmq          messaging/rabbitmq-mqtt-auth
synology-csi      synology-csi/0.10.1-client-info
EOF
}

app="${1:-}"
case "$app" in
  ""|-h|--help)
    usage
    exit 0
    ;;
  --list)
    list_apps
    exit 0
    ;;
esac

secret="${2:-}"
key="${3:-}"

case "$app" in
  mealie)
    namespace="mealie"
    secrets=("mealie-db")
    ;;
  donetick)
    namespace="donetick"
    secrets=("donetick-secret")
    ;;
  postgres)
    namespace="database"
    secrets=("postgres-secret" "postgres-app-secrets")
    ;;
  grafana)
    namespace="monitoring"
    secrets=("grafana-admin-credentials")
    ;;
  alertmanager-ntfy)
    namespace="monitoring"
    secrets=("alertmanager-ntfy")
    ;;
  speedtest)
    namespace="speedtest-tracker"
    secrets=("speedtest-tracker-secrets")
    ;;
  adguard)
    namespace="networking"
    secrets=("adguard-secret")
    ;;
  rabbitmq)
    namespace="messaging"
    secrets=("rabbitmq-mqtt-auth")
    ;;
  synology-csi)
    namespace="synology-csi"
    secrets=("0.10.1-client-info")
    ;;
  *)
    echo "Unknown app: $app" >&2
    echo "Run: hack/get-secret.sh --list" >&2
    exit 1
    ;;
esac

if [[ -n "$secret" ]]; then
  allowed=0
  for candidate in "${secrets[@]}"; do
    if [[ "$candidate" == "$secret" ]]; then
      allowed=1
      break
    fi
  done
  if [[ "$allowed" -ne 1 ]]; then
    echo "Secret '$secret' is not allowed for app '$app'." >&2
    echo "Run: hack/get-secret.sh --list" >&2
    exit 1
  fi
  secrets=("$secret")
fi

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  for secret_name in "${secrets[@]}"; do
    echo "# kubectl -n $namespace get secret $secret_name -o jsonpath='{.data.KEY}' | base64 -d"
  done
  exit 0
fi

if [[ ! -t 1 && "${ALLOW_NON_TTY:-0}" != "1" ]]; then
  echo "Refusing to write secrets to a non-TTY. Set ALLOW_NON_TTY=1 only if you really mean it." >&2
  exit 1
fi

echo "Sensitive output. Do not paste it into issues, logs, or chat." >&2
for secret_name in "${secrets[@]}"; do
  echo "== $namespace/$secret_name"
  if [[ -n "$key" ]]; then
    kubectl -n "$namespace" get secret "$secret_name" \
      -o "jsonpath={.data.$key}" | base64 -d
    echo
  else
    kubectl -n "$namespace" get secret "$secret_name" \
      -o 'go-template={{range $k,$v := .data}}{{$k}}={{$v|base64decode}}{{"\n"}}{{end}}'
  fi
done
