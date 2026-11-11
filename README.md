# Homelab Kubernetes Manifests

GitOps configuration for my homelab Kubernetes cluster.

The cluster is managed by **Argo CD** using an **app-of-apps** pattern:

- Argo CD watches this repository at `applications/`.
- The root kustomization renders a set of child Argo CD `Application` objects.
- Most child Applications deploy a pinned Helm chart.
- A few deploy plain Kustomize resources (for example, AdGuard Home).
- Storage comes from a Synology NAS over iSCSI (`synology-iscsi`) and NFS
  (`synology-nfs-subdir`).
- Ingress is Traefik, and secrets are managed with Sealed Secrets.

The goal of this repo is that `main` is always deployable. Argo CD does the
actual deployment; `kubectl apply` is only for bootstrapping or emergency
debugging.

---

## Start Here After a Break

Run this checklist when you come back to the cluster after a while:

1. **Update the repo and check for local work**

   ```sh
   cd ~/Repositories/manifests
   git fetch --all --prune
   git status
   ```

2. **Run the local validation suite**

   ```sh
   make validate
   ```

   This does not need cluster access. It lints YAML, builds every
   kustomization, validates the rendered Kubernetes objects with kubeconform,
   and runs kube-linter.

3. **Restore cluster access**

   ```sh
   kubectl config get-contexts
   kubectl get nodes -o wide
   ```

   If this fails with `the server has asked for the client to provide
   credentials`, see [Cluster Authentication](#cluster-authentication).

4. **Check overall cluster health**

   ```sh
   kubectl get pods -A -o wide
   kubectl get events -A --sort-by=.lastTimestamp | tail -40
   ```

5. **Check Argo CD**

   ```sh
   kubectl get applications -n argocd
   argocd app list
   ```

   Every Application should be `Synced` and `Healthy`. If something is not,
   see [Troubleshooting](#troubleshooting).

6. **Check for drift before making changes**

   ```sh
   argocd app diff applications
   argocd app diff <app-name>
   ```

7. **Open the UIs you care about**

   | What | URL |
   | --- | --- |
   | Argo CD | <http://boulder.local:8081> |
   | Grafana | <http://boulder.local:3000> |
   | Uptime Kuma | <https://kuma.lakotko.synology.me> |
   | AdGuard Home | <http://192.168.68.71:31628> |
   | Traefik dashboard | <http://192.168.68.71:8080/dashboard/> |

   `boulder.local` may need an entry in your workstation's `/etc/hosts`:

   ```text
   192.168.68.71 boulder.local
   ```

---

## Repository Layout

```text
.
├── Makefile                     # make tools / make validate / make render / make clean
├── hack/
│   ├── install-tools.sh         # downloads pinned validation tools into .bin/
│   ├── render-helm.py           # renders chart-backed Argo CD Applications
│   ├── render-helm.sh           # wrapper that uses the repo virtualenv
│   ├── render-helm.skip         # applications that cannot be rendered yet
│   └── validate.sh              # the validation pipeline
├── applications/
│   ├── applications.yaml        # app-of-apps: the root Argo CD Application
│   ├── kustomization.yaml       # includes platform/, observability/, apps/
│   ├── platform/                # cluster infrastructure
│   │   ├── argocd/              # Argo CD itself, ingress, AppProjects
│   │   ├── coredns/             # CoreDNS custom host entries
│   │   ├── nfs-subdir-external-provisioner/
│   │   ├── postgresql/          # Application + manifests/ (Postgres workload)
│   │   ├── rabbitmq/            # RabbitMQ operator + RabbitmqCluster CR
│   │   ├── sealed-secrets/      # Sealed Secrets controller
│   │   ├── synology-csi/        # Synology CSI driver
│   │   ├── synology-iscsi-storageclass/
│   │   └── traefik/             # Traefik HelmChartConfig
│   ├── observability/           # monitoring namespace + metrics/logs/uptime
│   │   ├── monitoring/          # Grafana, Loki, Prometheus, ingress, netpol
│   │   └── uptime-kuma/
│   └── apps/                    # user-facing applications
│       ├── adguard-home/        # Kustomize base + overlays/home
│       ├── donetick/            # Application, namespace, sealed secret, values
│       ├── mealie/              # Application + manifests/ (Kustomize workload)
│       └── ntfy/                # Application + values (HelmForge chart)
├── .github/workflows/validate.yaml
├── .editorconfig
├── .gitignore
├── .gitleaks.toml
├── .kube-linter.yaml
├── .pre-commit-config.yaml
└── .yamllint
```

### How the app-of-apps works

`applications/applications.yaml` is an Argo CD `Application` named
`applications`. It points at the `applications/` path in this repo and has
automated `prune` and `selfHeal` enabled.

When it syncs, the root `applications/kustomization.yaml` renders the child
`Application` objects. Argo CD then reconciles each child. A child is usually
one of:

- a Helm chart, pinned with `targetRevision`, or
- a Kustomize path inside this repo, such as
  `applications/apps/adguard-home/overlays/home`.

For apps that live in their own directory, keep the directory's
`kustomization.yaml` limited to the `Application` object (plus any resources
the child Application cannot create itself, such as a Helm app's namespace and
sealed secret). Put the child-reconciled workload in a subdirectory such as
`applications/apps/mealie/manifests`, and point the child `Application` at that
subdirectory. This lets the root kustomization list the app group without
applying the workload twice.

### Projects and namespaces

The root kustomization lists three group directories:

- `applications/platform` — cluster infrastructure and shared services
- `applications/observability` — metrics, logs, dashboards, and uptime
- `applications/apps` — user-facing applications

Each group maps to an Argo CD `AppProject` (`platform`, `observability`,
`apps`) defined under `applications/platform/argocd/projects/`. The projects
restrict which Git/Helm sources and destination namespaces each Application may
use. They carry `argocd.argoproj.io/sync-wave: "-10"` so they are created before
the child `Application` objects that reference them. The root `applications`
Application itself stays in the `default` project, because the custom projects
do not exist until it creates them.

Namespaces and projects do **not** have to be top-level folders. They are
ordinary Kustomize resources, so their location only needs to be reachable from
a kustomization. In this repo:

- AppProjects live with the Argo CD configuration, in
  `applications/platform/argocd/projects/`.
- Namespaces live with the group that owns them. `monitoring` is defined once in
  `applications/observability/namespace.yaml`, `database` is defined in
  `applications/platform/postgresql/manifests/namespace.yaml`, and the other
  namespaces stay inside their app directories.
- The root app's `destination.namespace` is `argocd`, since that is where the
  `Application` and `AppProject` objects it manages live. Destination
  namespaces for the child apps are declared per Application.

**Important:** do not run `kubectl apply -k applications` against the live
cluster during normal work. Argo CD owns these resources; manual applies cause
drift and confusing ownership. Use `kubectl diff` or `--dry-run=server`
instead.

---

## First-Time Setup

### 1. Install the validation tools

```sh
make tools
```

This downloads pinned binaries into `.bin/` and creates a Python virtual
environment in `.venv/` for yamllint. Both directories are git-ignored.

Pinned versions:

- kubeconform `v0.8.0`
- kube-linter `0.8.3`
- yamllint `1.38.0`

### 2. Install the pre-commit hook

```sh
pipx install pre-commit    # or: python3 -m pip install --user pre-commit
pre-commit install
```

The hook runs `gitleaks` before each commit. Run it manually across the whole
repo with:

```sh
pre-commit run --all-files
```

### 3. Confirm kubectl and Helm

```sh
kubectl version --client
helm version
```

Kustomize is built into modern `kubectl`; a separate `kustomize` binary is not
required.

---

## Cluster Authentication

The cluster API is expected at:

```text
https://192.168.68.71:6443
```

The kubeconfig is normally at `~/.kube/config`, with context name `default`.

Check what you are pointing at:

```sh
kubectl config current-context
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
```

### If kubectl says "the server has asked for the client to provide credentials"

This kubeconfig authenticates with a client certificate. That message normally
means the certificate has expired, or the kubeconfig belongs to a different
cluster.

Check the certificate dates:

```sh
kubectl config view --raw \
  -o jsonpath='{.users[0].user.client-certificate-data}' \
  | base64 -d \
  | openssl x509 -noout -subject -dates
```

The cluster appears to be **k3s**. Its admin kubeconfig lives on the server at
`/etc/rancher/k3s/k3s.yaml`.

#### Option A: copy a fresh kubeconfig from the server

From your workstation:

```sh
cp ~/.kube/config ~/.kube/config.bak.$(date +%Y%m%d)

ssh <user>@192.168.68.71 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config

# k3s writes 127.0.0.1; point it at the server's LAN address instead.
sed -i 's#https://127.0.0.1:6443#https://192.168.68.71:6443#' ~/.kube/config
chmod 600 ~/.kube/config

kubectl config use-context default
kubectl get nodes -o wide
```

Replace `<user>` with your SSH user. If `sudo` requires a TTY, use
`ssh -t <user>@192.168.68.71 'sudo cat /etc/rancher/k3s/k3s.yaml'`.

#### Option B: rotate an expired k3s certificate

On the server:

```sh
ssh <user>@192.168.68.71

sudo k3s certificate rotate
sudo systemctl restart k3s
sudo systemctl status k3s
```

Then repeat Option A to copy the regenerated kubeconfig.

You can also verify the cluster directly on the server without copying
anything:

```sh
ssh <user>@192.168.68.71 'sudo k3s kubectl get nodes -o wide'
```

### If you use multiple kubeconfigs

Merge or select explicitly:

```sh
export KUBECONFIG=~/.kube/config
kubectl config get-contexts
kubectl config use-context default
```

---

## Argo CD Access

Argo CD runs in the `argocd` namespace. The server is configured with
`server.insecure: "true"`, so it is reached over HTTP behind Traefik.

### UI through Traefik

```text
http://boulder.local:8081
```

Traefik exposes a dedicated `argocd` entry point on port `8081`.

### UI through port-forward (no DNS needed)

```sh
kubectl -n argocd get svc
kubectl -n argocd port-forward svc/argo-argocd-server 8080:80
```

Then open <http://localhost:8080>.

If `argo-argocd-server` is not the service name, pick the Argo CD server
service from the `kubectl get svc` output.

### Initial admin password

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

The username is `admin`. If the initial secret has already been removed, reset
the password with the Argo CD CLI:

```sh
argocd account update-password --account admin
```

### Argo CD CLI

Install a client version that matches the server, then log in:

```sh
# Linux amd64 example; substitute the correct release for your platform.
curl -sSL -o /tmp/argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 755 /tmp/argocd /usr/local/bin/argocd

argocd version --client
argocd login boulder.local:8081 --plaintext --username admin
```

`--plaintext` is required because the server is HTTP, not HTTPS.

Alternative login through port-forward:

```sh
kubectl -n argocd port-forward svc/argo-argocd-server 8080:80
argocd login localhost:8080 --plaintext --username admin
```

---

## Daily Workflow

1. **Create a branch**

   ```sh
   git switch -c my-change
   ```

2. **Edit the manifests**

   Keep changes small and focused. Pin image tags and chart versions when you
   can.

3. **Validate locally**

   ```sh
   make validate
   pre-commit run --all-files
   ```

4. **Do a server-side dry run if the cluster is reachable**

   ```sh
   kubectl diff -k applications
   kubectl apply --dry-run=server -k applications
   ```

5. **Inspect what Argo CD would render**

   ```sh
   argocd app manifests applications
   argocd app diff applications
   ```

6. **Commit and push**

   ```sh
   git add <files>
   git commit -m "describe the change"
   git push
   ```

7. **Let Argo CD sync, or sync manually**

   ```sh
   argocd app sync applications
   argocd app sync <app-name>
   ```

   The `applications` app has automated sync enabled, as do most child apps.
   Merging to `main` is normally enough.

---

## Validation

### `make validate`

Runs `hack/validate.sh`, which currently does the following:

1. `yamllint` on all git-tracked and non-ignored untracked YAML files.
2. Builds every `applications/**/kustomization.yaml` with `kubectl kustomize`.
3. Renders every chart-backed Argo CD `Application` with `helm template`.
   Inline `helm.values` are written to temporary files, and `$values/...`
   references are resolved against this checkout.
4. Runs `kubeconform` in strict mode against Kubernetes `1.33.0` schemas on
   both the Kustomize and Helm-rendered output. It also uses the Datree CRDs
   catalog for CRDs such as Argo CD `Application`, `SealedSecret`,
   `IngressRoute`, `HelmChartConfig`, and `RabbitmqCluster`.
   `CustomResourceDefinition` objects themselves are skipped because the
   Kubernetes JSON schema catalog does not publish a schema for that kind.
5. Runs `kubeconform` on standalone manifests under `applications/`
   (excluding `kustomization.yaml` and `values.yaml`).
6. Runs `kube-linter` on the Kustomize and Helm-rendered output.

Current baseline (at the time of writing):

```text
24 kustomizations build
11 chart-backed Applications render
157 Helm-rendered resources: 153 valid, 0 invalid, 0 errors, 4 skipped
206 Kustomize-rendered resources: 206 valid, 0 invalid, 0 skipped
84 standalone resources: 84 valid, 0 skipped
kube-linter: no lint errors
```

The numbers will change as manifests are added.

Override the Kubernetes version when needed:

```sh
KUBE_VERSION=1.34.0 make validate
```

### Render Helm charts by themselves

```sh
make render
```

This runs `hack/render-helm.sh` and writes one file per Application to
`.tmp/helm/`. It is useful when you want to inspect chart output without
running the whole validation pipeline:

```sh
make render
grep -n 'kind:' .tmp/helm/grafana.yaml
```

The renderer follows Argo CD's rules for value files:

- `$values/...` paths are resolved from this repository.
- Plain `valueFiles` entries are rejected for Helm repository sources,
  because Argo CD cannot read files from a Helm repository.
- Inline `helm.values` are applied last.

Applications that cannot be rendered yet are listed in
`hack/render-helm.skip` with a reason. The file is currently empty: all
chart-backed Applications render locally.

### What it does **not** cover yet

- Helm charts that pull values from a separate Git repository are not
  rendered locally.
- Cluster-specific admission, policy, and CRD behavior is not checked.
- Server-side validation requires a reachable cluster.
- Charts can render differently under a live cluster because of
  `.Capabilities`, `lookup`, and API discovery.

For a true server-side view, use Argo CD itself:

```sh
argocd app manifests <app-name> > /tmp/rendered.yaml
argocd app diff <app-name>
kubectl diff -k applications
```

### CI

`.github/workflows/validate.yaml` runs on pull requests, pushes to `main`, and
manual dispatches. It installs kubectl, Helm, and the pinned validation tools,
runs `make validate`, then scans for secrets with gitleaks. All steps are
failing steps; there are no `|| true` escape hatches.

### Individual checks

```sh
# Render the root app-of-apps
kubectl kustomize applications

# Render one Kustomize app
kubectl kustomize applications/apps/adguard-home/overlays/home

# YAML lint
.venv/bin/yamllint .

# Render every Helm chart
make render

# Structural lint on rendered output
kubectl kustomize applications > .tmp/rendered.yaml
.bin/kube-linter lint .tmp/rendered.yaml
.bin/kube-linter lint .tmp/helm
```

---

## Common Commands

### Cluster

```sh
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -40
kubectl get storageclass
kubectl get pvc -A
kubectl top nodes
kubectl top pods -A
```

### Argo CD

```sh
kubectl get applications -n argocd
kubectl get application <app-name> -n argocd -o yaml

argocd app list
argocd app get applications
argocd app get <app-name> --refresh
argocd app diff <app-name>
argocd app manifests <app-name>
argocd app sync <app-name>
argocd app history <app-name>
argocd app rollback <app-name> <history-id>
argocd app logs <app-name>
```

### Pods and workloads

```sh
kubectl -n <namespace> get pods
kubectl -n <namespace> describe pod <pod>
kubectl -n <namespace> logs deploy/<name> --tail=100 -f
kubectl -n <namespace> logs statefulset/<name> --tail=100 -f
kubectl -n <namespace> get events --sort-by=.lastTimestamp
kubectl -n <namespace> rollout status deploy/<name>
kubectl -n <namespace> rollout restart deploy/<name>
```

### Services, ingress, and storage

```sh
kubectl -n <namespace> get svc,ingressroute,pvc
kubectl -n <namespace> describe pvc <pvc>
kubectl get ingressroute -A
kubectl -n kube-system get svc traefik
```

### Port-forward examples

```sh
kubectl -n argocd port-forward svc/argo-argocd-server 8080:80
kubectl -n monitoring port-forward svc/grafana 3000:80
kubectl -n monitoring port-forward svc/prometheus-server 9090:80
kubectl -n messaging port-forward svc/rabbitmq 15672:15672
```

Service names can differ by chart version. Run `kubectl -n <namespace> get svc`
first.

### RabbitMQ MQTT

RabbitMQ exposes MQTT on `192.168.68.71:1883` through Traefik. The dedicated
non-admin user is `mqttuser`; its password is stored in the sealed
`messaging/rabbitmq-mqtt-auth` Secret:

```sh
kubectl -n messaging get secret rabbitmq-mqtt-auth \
  -o jsonpath='{.data.username}' | base64 -d; echo
kubectl -n messaging get secret rabbitmq-mqtt-auth \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

The `rabbitmq-mqtt-user` PostSync Job recreates the user and its vhost
permissions after each sync. Change the password by re-sealing the Secret,
then re-running the sync.

### Helm

Argo CD renders Helm charts with `helm template`, so `helm list` usually only
shows releases installed directly with Helm (for example, Argo CD itself).

```sh
helm list -A
helm -n argocd list
helm -n argocd get values <release>
helm -n argocd history <release>
```

---

## Sealed Secrets

The Sealed Secrets controller runs in `kube-system` (chart `sealed-secrets`
`2.17.0`).

Seal a plaintext Secret without sending it to the cluster:

```sh
kubeseal \
  --controller-name sealed-secrets \
  --controller-namespace kube-system \
  --format yaml \
  < plaintext-secret.yaml \
  > sealed-secret.yaml
```

Rules:

- **Never commit plaintext Secrets.** `.gitignore` blocks the known plaintext
  filenames, and the pre-commit `gitleaks` hook catches most accidents.
- SealedSecret files are safe to commit.
- SealedSecrets are encrypted to the controller's key. If that key is lost,
  existing SealedSecrets cannot be decrypted. Back up the controller key:

  ```sh
  kubectl -n kube-system get secret \
    -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
    -o yaml > sealed-secrets-key-backup.yaml
  ```

  Store that backup offline and encrypted; do not commit it.

The local file `cluster-sealed-secrets-master.key` is a backup of the
controller's keyring, including the private keys. Treat it as highly sensitive,
keep it out of git, and store it offline. It can also be used to seal secrets
while the cluster API is unavailable:

```sh
# Extract the newest controller certificate once.
.venv/bin/python - <<'PY'
import base64, pathlib, yaml
items = []
for doc in yaml.safe_load_all(open("cluster-sealed-secrets-master.key")):
    for item in doc.get("items", []):
        md = item.get("metadata", {})
        if md.get("name", "").startswith("sealed-secrets-key"):
            items.append(item)
items.sort(key=lambda i: i["metadata"].get("creationTimestamp", ""))
pathlib.Path(".tmp/sealed-secrets").mkdir(parents=True, exist_ok=True)
pathlib.Path(".tmp/sealed-secrets/active.crt").write_bytes(
    base64.b64decode(items[-1]["data"]["tls.crt"])
)
PY

kubeseal --cert .tmp/sealed-secrets/active.crt --format yaml \
  < plaintext-secret.yaml > sealed-secret.yaml
```

The controller retains old keys, so a secret sealed with an older key in the
backup can still be decrypted. If you are unsure which key is current, seal
with the newest key in the backup and verify the SealedSecret against the
cluster when it is reachable.

### Re-sealing after a controller key change

If the controller is reinstalled and its key changes, old SealedSecrets will
fail to decrypt. Restore the old key first if possible; otherwise re-seal each
plaintext secret with the new controller certificate.

---

## Inventory

### Argo CD Applications

| Application | Namespace | Source | Notes |
| --- | --- | --- | --- |
| `applications` | `argocd` | Git path `applications` | App-of-apps; auto prune/self-heal |
| `adguard-home` | `networking` | Git path `applications/apps/adguard-home/overlays/home` | Only pure Kustomize workload; pinned image and probes |
| `authelia` | `auth` | Git path `applications/platform/authelia/manifests` | 2 replicas; Postgres storage; Redis sessions; OIDC provider |
| `argocd` | `argocd` | Helm `argo-cd` `9.5.14` | Self-managing; UI on 8081; old `argocd-*` release and duplicate RBAC removed |
| `alloy` | `monitoring` | Helm `alloy` `1.8.1` | Ships pod logs to Loki |
| `grafana` | `monitoring` | Helm `grafana` `7.3.7` | 10Gi iSCSI; Prometheus/Loki datasources; UI on 3000 |
| `loki` | `monitoring` | Helm `loki` `6.55.0` | SingleBinary; 20Gi iSCSI; fed by Alloy; memcached caches disabled to save memory |
| `prometheus` | `monitoring` | Helm `prometheus` `25.21.0` | ClusterIP; alert rules |
| `nfs-subdir-provisioner` | `nfs-provisioner` | Helm `4.0.18` | Creates `synology-nfs-subdir` |
| `rabbitmq-operator` | `rabbitmq-system` | Git path `config/installation` | Operator `v2.12.0`, image pinned to `2.12.0` |
| `sealed-secrets` | `kube-system` | Helm `2.17.0` | Controller |
| `synology-csi` | `synology-csi` | Helm `0.10.1` | iSCSI driver |
| `uptime-kuma` | `monitoring` | Helm `app-template` `3.7.2` | 5Gi iSCSI |
| `donetick` | `donetick` | Helm `app-template` `3.7.2` | Wired in; Postgres `donetick` DB |
| `mealie` | `mealie` | Git path `applications/apps/mealie/manifests` | Wired in; Postgres `mealie` DB |
| `paperless` | `paperless` | Git path `applications/apps/paperless/manifests` | Wired in; Postgres `paperless` DB; Authelia OIDC |
| `speedtest-tracker` | `speedtest-tracker` | Git path `applications/apps/speedtest-tracker/manifests` | Wired in; Postgres `speedtest` DB; Apprise sidecar |
| `ntfy` | `ntfy` | Helm `ntfy` `1.7.1` (HelmForge) | Wired in; SQLite on `synology-iscsi` |
| `postgresql` | `database` | Git path `applications/platform/postgresql/manifests` | Wired in; 10Gi iSCSI; PostSync DB init job |

Additional resources not represented as child Applications:

| Resource | Namespace | Notes |
| --- | --- | --- |
| `rabbitmq` RabbitmqCluster | `messaging` | 1 replica, 20Gi iSCSI |
| `synology-iscsi` StorageClass | cluster-wide | Synology CSI, iSCSI, Retain |
| `traefik` HelmChartConfig | `kube-system` | Extra entry points and dashboard |
| `coredns-custom` ConfigMap | `kube-system` | `hoist.local` -> `192.168.68.138` |
| `postgres` StatefulSet | `database` | Managed by the `postgresql` child Application |
| `postgres-init-apps` Job | `database` | Creates the `mealie`, `donetick`, `paperless`, `speedtest`, and `authelia` roles/databases |
| `postgres-app-secrets` | `database` | Sealed app DB passwords used by the init Job |
| `authelia-db` | `auth` | Sealed Authelia Postgres password |
| `authelia-redis` Deployment/Service | `auth` | Valkey session store for Authelia HA |
| `mealie-db` | `mealie` | Sealed Mealie DB password |
| `donetick-secret` | `donetick` | Sealed Donetick DB password and JWT secret |
| `paperless-secrets` | `paperless` | Sealed Paperless DB/app/OIDC credentials |
| `speedtest-db` | `speedtest-tracker` | Sealed Speedtest DB password |
| `mealie` Deployment/PVC/Service | `mealie` | Managed by the `mealie` child Application |
| `paperless` Deployment/PVC/Service | `paperless` | Managed by the `paperless` child Application |
| `speedtest-tracker` Deployment/PVC/Service | `speedtest-tracker` | Managed by the `speedtest-tracker` child Application |

### PostgreSQL databases

The `postgresql` child Application runs a single `postgres` StatefulSet in the
`database` namespace. The `postgres-init-apps` PostSync Job creates five
application roles/databases idempotently:

| Role/database | Password source | Consumer |
| --- | --- | --- |
| `mealie` | `mealie-db` Secret in `mealie` | Mealie |
| `donetick` | `donetick-secret` Secret in `donetick` | Donetick |
| `paperless` | `paperless-secrets` Secret in `paperless` | Paperless-ngx |
| `speedtest` | `speedtest-db` Secret in `speedtest-tracker` | Speedtest Tracker |
| `authelia` | `authelia-db` Secret in `auth` | Authelia |

The Job also reads `postgres-app-secrets` in `database`, which contains the same
passwords. Keep the two SealedSecrets in sync if you rotate a password.

### Authelia HA

Authelia runs two replicas in `auth` with shared state:

- PostgreSQL storage (`storage.postgres`) in the `authelia` database.
- Redis/Valkey sessions (`session.redis`) via `authelia-redis` in `auth`.
- Shared `authelia-secrets` values: session secret, storage encryption key,
  reset-password JWT secret, OIDC HMAC, and JWKS.
- `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0`.

The old `authelia-config` PVC and `authelia-sqlite-backup` CronJob are retained
only as a rollback path. Authelia no longer mounts that PVC. The Postgres dump
is included in the central backup CronJob.

### Paperless-ngx OIDC

Paperless-ngx uses the Authelia OIDC provider directly; there is no
forward-auth middleware on its Ingress. The Authelia client is
`paperless-ngx` with callback
`https://paperless.lakotko.synology.me/accounts/oidc/authelia/login/callback/`
and scopes `openid`, `profile`, `email`, and `groups`.

Users in Authelia's `admins` group are promoted to Paperless superuser on
login. The local `paperless-admin` account remains as break-glass access; its
password is in the `paperless-secrets` SealedSecret. The Synology reverse proxy
must forward `paperless.lakotko.synology.me` to Traefik at
`http://192.168.68.71:80` and preserve the Host header, like the Mealie and
Donetick rules.

### Endpoints and ports

| Endpoint | Address |
| --- | --- |
| Kubernetes API | `https://192.168.68.71:6443` |
| Argo CD | `http://boulder.local:8081` |
| Grafana | `http://boulder.local:3000` |
| Uptime Kuma | `https://kuma.lakotko.synology.me` |
| Mealie | `https://meals.lakotko.synology.me` |
| Donetick | `https://tasks.lakotko.synology.me` |
| Paperless-ngx | `https://paperless.lakotko.synology.me` |
| Homepage | `https://home.lakotko.synology.me` |
| ntfy | `https://ntfy.lakotko.synology.me` |
| RabbitMQ MQTT | `mqtt://192.168.68.71:1883` |
| RabbitMQ management | `http://localhost:15672` after `kubectl -n messaging port-forward svc/rabbitmq 15672:15672` |
| AdGuard web | `http://192.168.68.71:31628` |
| AdGuard DNS (UDP) | `192.168.68.71:30915` |
| AdGuard DNS (TCP) | `192.168.68.71:30916` |
| Traefik dashboard | `http://192.168.68.71:8080/dashboard/` |
| Synology NAS | `192.168.68.138` |

### Storage

| StorageClass | Backing store | Typical use |
| --- | --- | --- |
| `synology-iscsi` | Synology iSCSI, `/volume1` | Databases, SQLite apps, and single-writer workloads |
| `synology-nfs-subdir` | NFS `192.168.68.138:/volume1/k8s-nfs` | Mealie shared media and other ReadWriteMany data; default class |

`synology-nfs` is **not** a real StorageClass in this cluster. Use
`synology-nfs-subdir` for NFS.

`synology-nfs-subdir` is configured with `mountOptions: [vers=4.1]` in the
`nfs-subdir-external-provisioner` Helm values. NFSv3 was a temporary
workaround: the real write problem was the Synology Windows ACL, which denied
non-root pod UIDs until an explicit `everyone` allow ACE was added. With that
ACL in place, NFSv4.1 works normally. Existing PVs keep their old mount options
until their `spec.mountOptions` is patched or the PV/PVC is recreated.

Mealie keeps its media on `synology-nfs-subdir` because it is shared
ReadWriteMany data, and runs as UID/GID 911; the NFS export must allow that UID.
ntfy uses `synology-iscsi` because SQLite on NFS is unsafe. Verify a non-root
write from a test pod before relying on NFS for a new application.

### SQLite single-writer workloads

Any application that keeps SQLite on a ReadWriteOnce volume must use the
`Recreate` Deployment strategy, not `RollingUpdate`. On a single node both the
old and new pods can mount the same RWO volume, and concurrent SQLite writers
can corrupt the database.

Current SQLite-backed workloads:

| Workload | Strategy | Notes |
| --- | --- | --- |
| `adguard-home` | `Recreate` | session DB on `synology-iscsi` |
| `grafana` | `Recreate` | `grafana.db` on `synology-iscsi` |
| `ntfy` | `Recreate` | chart default; SQLite on `synology-iscsi` |
| `uptime-kuma` | `Recreate` | `kuma.db` on `synology-iscsi` |
| `speedtest-tracker` | `Recreate` | now Postgres; kept for the legacy PVC |

Postgres-backed apps (`mealie`, `donetick`, `paperless`, `speedtest-tracker`,
and now `authelia`) may use rolling updates when their shared data volumes are
ReadWriteMany or their state is external. Authelia's legacy SQLite PVC is no
longer mounted by the Deployment.

### Capacity

The cluster is a single node with roughly 15.4Gi of allocatable memory. Most
workloads now declare requests and limits so scheduling is predictable and a
runaway pod cannot consume the node.

Loki's chart defaults include two memcached caches that requested about 11Gi of
memory while using only tens of MiB. They are disabled in
`applications/observability/monitoring/loki.yaml` because the homelab runs
SingleBinary Loki with filesystem/TSDB storage. Re-enable them only if Loki is
split into read/write/backend components or ingestion grows enough to need a
shared cache.

The rendered workload requests total about 4Gi of memory and 1.3 CPU. The
RabbitMQ operator and broker are managed outside the rendered Helm output; with
their requests included, the node is roughly 5.5Gi committed, leaving room for
bursts and future applications. Check actual pressure with:

```sh
kubectl top node
kubectl get pods -A -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,CPU:.spec.containers[*].resources.requests.cpu,MEM:.spec.containers[*].resources.requests.memory'
```

---

## Troubleshooting

### Argo CD shows `OutOfSync` or `Degraded`

```sh
argocd app get <app-name> --refresh
argocd app diff <app-name>
argocd app manifests <app-name> | less

# Release names can vary; list the pods and logs the one you need.
kubectl -n argocd get pods
kubectl -n argocd logs <application-controller-pod> --tail=100
kubectl -n argocd logs <repo-server-pod> --tail=100
```

Common causes:

- A Helm value references a file that does not exist or is not in a
  multi-source `$values` repo.
- A CRD or namespace does not exist yet.
- A PVC is stuck because the StorageClass name is wrong.
- An image tag does not exist.

### Pod is `Pending`

```sh
kubectl -n <namespace> describe pod <pod>
kubectl -n <namespace> describe pvc <pvc>
kubectl get storageclass
```

Check the StorageClass name and whether the PVC is `Bound`.

### Pod is `ImagePullBackOff` or `ErrImagePull`

```sh
kubectl -n <namespace> describe pod <pod>
kubectl -n <namespace> get secret
```

Check the image tag and any registry pull secret.

### Service has no endpoints

```sh
kubectl -n <namespace> get endpoints <service>
kubectl -n <namespace> get pods --show-labels
```

This usually means the Service selector does not match the pod labels.

### DNS or ingress does not work

```sh
kubectl -n kube-system get pods
kubectl -n kube-system logs deploy/coredns --tail=100
kubectl -n kube-system logs deploy/traefik --tail=100
kubectl get ingressroute -A
```

Remember that `boulder.local` may need a local `/etc/hosts` entry.

### SealedSecret will not decrypt

```sh
kubectl -n kube-system logs deploy/sealed-secrets --tail=100
kubectl -n kube-system get secret \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active
```

If the controller key changed, restore the old key or re-seal the secret.

### k3s itself

```sh
ssh <user>@192.168.68.71
sudo systemctl status k3s
sudo journalctl -u k3s -f
sudo k3s kubectl get nodes
```

---

## Known Gaps and Stabilization Checklist

These are the current rough edges in the repo. Check them off as they are
fixed.

### Wiring and correctness

- [x] Wire `postgresql` in as a child Application
  (`applications/platform/postgresql/application.yaml`).
- [x] Wire `ntfy` into `applications/kustomization.yaml` and replace its dead
  chart repository with HelmForge `ntfy` `1.7.1`.
- [x] Wire `mealie` and `donetick` into the root app-of-apps.
- [x] Add the `postgres-init-apps` PostSync Job, which creates the `mealie`
  and `donetick` roles/databases idempotently.
- [x] Seal the `mealie-db`, `donetick-secret`, and `postgres-app-secrets`
  values and commit the SealedSecrets.
- [x] Verify the `postgres-init-apps` Job succeeds on the first cluster sync.
- [x] Move ntfy to `synology-iscsi`; SQLite on NFS is unsafe.
- [x] Keep Mealie media on `synology-nfs-subdir` so it remains shared
  ReadWriteMany data.
- [x] Configure `synology-nfs-subdir` to mount new volumes with `vers=4.1`
  after fixing the Synology Windows ACL.
- [x] Patch or recreate existing NFS PVs so they use `vers=4.1`.
- [x] Verify Mealie can write to `mealie-media` as UID/GID 911.
- [x] Remove the old `ntfy-ntfy-data` NFS PVC once ntfy is healthy on iSCSI.
- [x] Delete the Released ntfy NFS PV.
- [x] Set real hostnames: `meals.lakotko.synology.me` for Mealie,
  `tasks.lakotko.synology.me` for Donetick, and
  `ntfy.lakotko.synology.me` for ntfy.
- [x] Remove the stale duplicate
  `applications/apps/adguard-home/overlays/home/application.yaml`.
- [x] Fix the Argo CD IngressRoute service name to `argo-argocd-server`, which
  matches the `argo` Helm release.
- [x] Remove the stale `rabbitmq-values` ConfigMap and `rabbitmq-auth`
  SealedSecret from the repo.
- [x] Remove the orphaned Bitnami `messaging/rabbitmq` StatefulSet and its old
  8Gi NFS PVC after confirming they hold no data.
- [x] Delete the Released RabbitMQ NFS PV.
- [x] Confirm the retired NAS folders are gone:
  - `/volume1/k8s-nfs/ntfy-ntfy-ntfy-data-pvc-e417e1f1-97ac-4c31-8182-d89a95dddad7`
  - `/volume1/k8s-nfs/messaging-data-rabbitmq-0-pvc-dc751ff6-5697-451b-8960-7650503554ab`
- [x] Verify the pinned `rabbitmq-cluster-operator` `v2.12.0` reconciles the
  `RabbitmqCluster` into a `rabbitmq-server` StatefulSet.
- [ ] Verify the `postgres` security context on the cluster. It now runs as
  UID/GID 70 and needs the CSI volume to honor `fsGroup`.

### Hardening

- [x] Pin AdGuard Home to `adguard/adguardhome:v0.107.80` instead of `latest`.
- [x] Add startup, liveness, and readiness probes to AdGuard Home.
- [x] Set AdGuard's Deployment strategy to `Recreate`; the PVC is single-writer.
- [x] Replace deprecated `commonLabels` with `labels` in the kustomizations.
- [x] Add resource requests and limits across the platform, monitoring, and
  application workloads.
- [x] Add Pod Security Admission labels. Application and platform namespaces
  enforce `baseline` with `restricted` audit/warn; `monitoring` and
  `synology-csi` enforce `privileged` because their node agents need host
  paths and host networking.
- [x] Add `LimitRange` defaults/maxima and namespace `ResourceQuota`s to the
  application and platform namespaces. `monitoring` has a `LimitRange` only.
- [x] Add default-deny ingress plus explicit allow policies for `mealie`,
  `donetick`, and `ntfy`. Each allows Traefik/kube-system, monitoring,
  same-namespace traffic, and kubelet probes from the node IP.
- [ ] Add default-deny egress policies. Egress is still open for the guarded
  namespaces.
- [x] Disable Loki's default memcached caches; they requested about 11Gi on a
  single-node deployment that uses filesystem/TSDB storage.
- [ ] Decide whether Grafana's SQLite volume needs a longer-term fix. It is
  currently healthy, but earlier iSCSI I/O errors caused thousands of restarts.
- [x] Add a log shipper (Grafana Alloy) so Loki receives application logs.
- [x] Add Prometheus alert rules for node memory, pod restarts, Argo CD sync
  state, and PVC usage.
- [x] Wire Alertmanager to the ntfy `alerts` topic. A test alert was delivered.
- [x] Provision Grafana datasources and dashboards as code.
- [x] Verify the Grafana datasources, the homelab dashboard, and Loki log
  ingestion after sync.
- [ ] Add `CreateNamespace` sync options where a child app targets a namespace
  Argo CD does not create.
- [x] Remove the orphaned old Argo CD `argocd-*` workloads from the `argocd`
  namespace. The old controller was already scaled to zero; its Deployments,
  StatefulSet, Services, and Ingress were then deleted. Shared configuration,
  secrets, and shared service accounts were left in place; duplicate old RBAC
  was removed in the next item.
- [x] Remove the orphaned `sealed-secrets-controller` Deployment and Services
  in `kube-system`, leaving the active `sealed-secrets` controller in place.
- [x] Remove the old Helm release metadata and duplicate RBAC. The inert
  `argocd` and `sealed-secrets` release records and the old `argocd-*` and
  `sealed-secrets-controller` RBAC were deleted after confirming the active
  `argo-argocd-*` and `sealed-secrets` RBAC cover the shared service accounts.
  The shared `ClusterRole secrets-unsealer` and the active controller remain.

### Validation and CI

- [x] Render Helm charts in `make validate` (`hack/render-helm.sh`).
- [x] Replace the `ntfy` chart source and remove it from
  `hack/render-helm.skip`.
- [x] Add a CI workflow that runs `make validate` on pull requests.
- [ ] Do not merge the existing `feat/add-github-actions` branch as-is: it
  uses abandoned `kubeval`, has `|| true`, and installs an unpinned
  kustomize. The new workflow supersedes it.
- [ ] Add server-side dry-run to CI once a safe, read-only cluster credential
  exists.

### Secrets

- [ ] Seal the remaining plaintext secrets and delete the working copies.
- [x] Back up the Sealed Secrets controller keyring; the local backup is
  `cluster-sealed-secrets-master.key`.
- [ ] Encrypt the keyring backup and store it offline. The local file is still
  plaintext; use `gpg --symmetric --cipher-algo AES256` and remove the plaintext
  copy after verifying the encrypted copy. Never commit either file.

---

## Security Notes

- This repo should be treated as containing cluster configuration, not
  plaintext credentials.
- SealedSecrets are safe to commit; plaintext Secrets are not.
- The pre-commit hook runs `gitleaks`, but it is not a substitute for care.
- The Traefik dashboard is enabled with `--api.insecure=true`. Keep it on the
  trusted LAN; do not expose it to the internet.
- Argo CD is running with `server.insecure: "true"` because TLS terminates at
  Traefik. Do not expose port `8081` publicly.
