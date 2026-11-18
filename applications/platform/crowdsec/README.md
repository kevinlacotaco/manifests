# CrowdSec

CrowdSec runs the Security Engine (log agent), Local API, and AppSec component.
The Traefik bouncer plugin is installed by the k3s Traefik addon and is attached
to the Homepage Ingress only for phase 1 testing.

## Components

| Component | Service | Port |
| --- | --- | --- |
| Local API | `crowdsec-service.crowdsec.svc.cluster.local` | 8080 |
| LAPI metrics | `crowdsec-service.crowdsec.svc.cluster.local` | 6060 |
| AppSec | `crowdsec-appsec-service.crowdsec.svc.cluster.local` | 7422 |
| AppSec metrics | `crowdsec-appsec-service.crowdsec.svc.cluster.local` | 6060 |

The LAPI keeps its SQLite database and cscli credentials on two 1Gi
`synology-iscsi` PVCs. The agent reads Traefik's JSON access log from
`/var/log/containers` and parses it with the `crowdsecurity/traefik` collection.
AppSec loads `crowdsecurity/virtual-patching` and 207 in-band rules.

Prometheus scrapes the LAPI and AppSec metrics through the scrape jobs in
`applications/observability/monitoring/prometheus.yaml`.

## Bouncer key

The bouncer key is generated once and stored as a SealedSecret in both
`crowdsec` and `kube-system`:

* `crowdsec/crowdsec-bouncer-key` registers `BOUNCER_KEY_TRAEFIK` with the LAPI.
* `kube-system/crowdsec-bouncer-key` is mounted into Traefik at
  `/etc/traefik/crowdsec/BOUNCER_KEY_TRAEFIK`.

The Middleware reads it with `crowdsecLapiKeyFile`; the key is never inlined in
the Middleware or Helm values. The plugin's LAPI key file support is documented
in the upstream Kubernetes example.

## Phase 1 test host

Only the Homepage Ingress
(`home.lakotko.synology.me`) uses
`kube-system-crowdsec-bouncer@kubernetescrd`. It is fail-open:

* `updateMaxFailure: -1` allows traffic when the LAPI is unreachable.
* `crowdsecAppsecFailureBlock: false` and
  `crowdsecAppsecUnreachableBlock: false` allow traffic when AppSec errors.

Keep the bouncer on this single host until these checks pass after a Synology
`X-Forwarded-For` change.

## Requirements and known limitations

### Real client IP

Traefik trusts `192.168.68.138/32` and the pod CIDR as forwarded-header sources.
The Synology reverse proxy in front of Traefik must send the original client in
`X-Forwarded-For`. Today it does not: a request through
`https://home.lakotko.synology.me` arrives at Traefik as `ClientHost: 10.42.0.0`,
so the bouncer cannot distinguish individual external clients. Configure the
Synology reverse proxy to forward `X-Forwarded-For` before enabling the bouncer
globally. Do not enable enforcement globally until that is verified.

### Boulder inotify limit

CrowdSec opens an fsnotify watcher for file sources even with
`poll_without_inotify: true`. Boulder has exhausted
`fs.inotify.max_user_instances`, so the agent crash-loops there. The chart's
agent is therefore scheduled off boulder and reads the Traefik log on hauler,
where Traefik currently runs. Raise the host limit (for example
`fs.inotify.max_user_instances=8192` via the host configuration) and remove the
`agent.affinity` block in `application.yaml` to restore a two-node DaemonSet.

### Plugin download

Traefik downloads the plugin from GitHub at startup. The `kube-system` Traefik
pods need egress to GitHub; a failed download prevents Traefik from starting.

## Verification

```bash
kubectl -n crowdsec get pods,pvc,sealedsecret
kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli lapi status
kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli bouncers list
kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli decisions list

# Baseline (Homepage)
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H 'Host: home.lakotko.synology.me' \
  -H 'X-Forwarded-For: 192.168.68.109' \
  http://192.168.68.71/

# Ban, verify 403, remove, and wait for the live-mode cache to expire
kubectl -n crowdsec exec deploy/crowdsec-lapi -- \
  cscli decisions add --ip 192.168.68.109 --duration 3m
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H 'Host: home.lakotko.synology.me' \
  -H 'X-Forwarded-For: 192.168.68.109' \
  http://192.168.68.71/
kubectl -n crowdsec exec deploy/crowdsec-lapi -- \
  cscli decisions delete --ip 192.168.68.109

# AppSec virtual patching
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H 'Host: home.lakotko.synology.me' \
  -H 'X-Forwarded-For: 192.168.68.188' \
  http://192.168.68.71/.env
```

Expected: `200` baseline, `403` while banned, `403` for `/.env`, and the
Homepage remains `200` if the LAPI or AppSec Service is unreachable.
