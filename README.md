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
   | Uptime Kuma | <http://kuma.192.168.68.71.nip.io> |
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
│   ├── kustomization.yaml       # lists every Application that is wired in
│   ├── adguard-home/            # Kustomize base + overlays/home
│   ├── argocd/                  # Argo CD itself (Helm)
│   ├── coredns/                 # CoreDNS custom host entries
│   ├── monitoring/              # Grafana, Loki, Prometheus, ingress, netpol
│   ├── nfs-subdir-external-provisioner/
│   ├── rabbitmq/                # RabbitMQ operator + RabbitmqCluster CR
│   ├── sealed-secrets/          # Sealed Secrets controller
│   ├── synology-csi/            # Synology CSI driver
│   ├── synology-iscsi-storageclass/
│   ├── traefik/                 # Traefik HelmChartConfig
│   ├── uptime-kuma/
│   ├── donetick/                # not wired in yet
│   ├── mealie/                  # not wired in yet
│   ├── ntfy/                    # not wired in yet
│   └── postgresql/              # not wired in yet
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
  `applications/adguard-home/overlays/home`.

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
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Then open <http://localhost:8080>.

If `argocd-server` is not the service name, pick the Argo CD server service
from the `kubectl get svc` output.

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
kubectl -n argocd port-forward svc/argocd-server 8080:80
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
16 kustomizations build
9 chart-backed Applications render
149 Helm-rendered resources: 145 valid, 0 invalid, 0 errors, 4 skipped (CRDs)
71 Kustomize-rendered resources: 71 valid, 0 invalid, 0 skipped
46 standalone resources: 46 valid, 0 skipped
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
`hack/render-helm.skip` with a reason. The current entry is `ntfy`, whose
chart repository (`charts.ntfy.sh`) no longer resolves. Remove the entry once
the chart source is replaced.

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
kubectl kustomize applications/adguard-home/overlays/home

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
kubectl -n argocd port-forward svc/argocd-server 8080:80
kubectl -n monitoring port-forward svc/grafana 3000:80
kubectl -n monitoring port-forward svc/prometheus-server 9090:80
kubectl -n messaging port-forward svc/rabbitmq 15672:15672
```

Service names can differ by chart version. Run `kubectl -n <namespace> get svc`
first.

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

The local file `cluster-sealed-secrets-master.key` is a plaintext Kubernetes
Secret dump, **not** the Sealed Secrets controller key. Treat it as sensitive
and keep it out of git.

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
| `adguard-home` | `networking` | Git path `applications/adguard-home/overlays/home` | Only pure Kustomize workload |
| `argocd` | `argocd` | Helm `argo-cd` `9.5.14` | Self-managing; UI on 8081 |
| `grafana` | `monitoring` | Helm `grafana` `7.3.7` | 10Gi iSCSI; UI on 3000 |
| `loki` | `monitoring` | Helm `loki` `6.55.0` | SingleBinary; 20Gi iSCSI |
| `prometheus` | `monitoring` | Helm `prometheus` `25.21.0` | ClusterIP |
| `nfs-subdir-provisioner` | `nfs-provisioner` | Helm `4.0.18` | Creates `synology-nfs-subdir` |
| `rabbitmq-operator` | `rabbitmq-system` | Git path `config/installation` | Operator `v2.12.0` |
| `sealed-secrets` | `kube-system` | Helm `2.17.0` | Controller |
| `synology-csi` | `synology-csi` | Helm `0.10.1` | iSCSI driver |
| `uptime-kuma` | `monitoring` | Helm `app-template` `3.7.2` | 5Gi iSCSI |
| `donetick` | `donetick` | Helm `app-template` `3.7.2` | Not wired into root |
| `ntfy` | `ntfy` | Helm `ntfy` `0.18.1` | Not wired; chart repo dead, skipped by renderer |

Additional resources not represented as child Applications:

| Resource | Namespace | Notes |
| --- | --- | --- |
| `rabbitmq` RabbitmqCluster | `messaging` | 1 replica, 20Gi iSCSI |
| `synology-iscsi` StorageClass | cluster-wide | Synology CSI, iSCSI, Retain |
| `traefik` HelmChartConfig | `kube-system` | Extra entry points and dashboard |
| `coredns-custom` ConfigMap | `kube-system` | `hoist.local` -> `192.168.68.138` |
| `postgres` StatefulSet | `default` | Raw manifest; not wired |
| `mealie` Deployment/PVC/Service | `mealie` | Raw manifest; not wired |

### Endpoints and ports

| Endpoint | Address |
| --- | --- |
| Kubernetes API | `https://192.168.68.71:6443` |
| Argo CD | `http://boulder.local:8081` |
| Grafana | `http://boulder.local:3000` |
| Uptime Kuma | `http://kuma.192.168.68.71.nip.io` |
| AdGuard web | `http://192.168.68.71:31628` |
| AdGuard DNS (UDP) | `192.168.68.71:30915` |
| AdGuard DNS (TCP) | `192.168.68.71:30916` |
| Traefik dashboard | `http://192.168.68.71:8080/dashboard/` |
| Synology NAS | `192.168.68.138` |

### Storage

| StorageClass | Backing store | Typical use |
| --- | --- | --- |
| `synology-iscsi` | Synology iSCSI, `/volume1` | Databases and single-writer workloads |
| `synology-nfs-subdir` | NFS `192.168.68.138:/volume1/k8s-nfs` | Shared ReadWriteMany data; default class |

`synology-nfs` is referenced by some unfinished manifests but is **not** a
real StorageClass in this cluster. Use `synology-nfs-subdir` for NFS.

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

- [ ] Wire `mealie`, `postgresql`, `ntfy`, and `donetick` into
  `applications/kustomization.yaml` only after their manifests are fixed.
- [ ] Add an Argo CD `Application` for `mealie` and `postgresql` (currently
  raw manifests only).
- [ ] Fix `mealie` and `ntfy` to use `synology-nfs-subdir` instead of the
  nonexistent `synology-nfs` StorageClass.
- [ ] Fix `ntfy`'s Helm values reference. A chart-only source cannot read
  `values.yaml` from this Git repo; use a multi-source `$values` setup like
  `uptime-kuma`.
- [ ] Fix `donetick`'s values source. It currently points at
  `applications/uptime-kuma/values.yaml`.
- [ ] Fix `donetick`'s database host, missing `donetick-secret`, and
  placeholder hostname.
- [ ] Fix `mealie`'s Deployment namespace, missing `mealie-data` PVC, database
  hostname, probes, and image tag.
- [ ] Fix the `postgres` NetworkPolicy: clients must carry the
  `requires-db: postgres` label, or the policy must be widened.
- [ ] Remove the unused `postgres-pvc`.
- [ ] Remove the stale duplicate
  `applications/adguard-home/overlays/home/application.yaml`; it points at the
  wrong path (`apps/adguard/overlays/home`).
- [ ] Remove or repurpose the unused `rabbitmq-values` ConfigMap and the
  possibly unused `rabbitmq-auth` SealedSecret.
- [ ] Verify the Argo CD Service name. The release name is `argo`, but the
  IngressRoute targets `argocd-server`.

### Hardening

- [ ] Pin floating image tags: AdGuard `latest`, Mealie `v3`, Donetick
  `latest`.
- [ ] Add liveness and readiness probes to AdGuard Home.
- [ ] Replace deprecated `commonLabels` with `labels` in the kustomizations
  that still use it.
- [ ] Add resource requests and limits where they are missing.
- [ ] Review `postgres` `imagePullPolicy: Always` and pin a minor version.
- [ ] Add `CreateNamespace` sync options where a child app targets a namespace
  Argo CD does not create.

### Validation and CI

- [x] Render Helm charts in `make validate` (`hack/render-helm.sh`).
- [ ] Replace the `ntfy` chart source and remove it from
  `hack/render-helm.skip`.
- [x] Add a CI workflow that runs `make validate` on pull requests.
- [ ] Do not merge the existing `feat/add-github-actions` branch as-is: it
  uses abandoned `kubeval`, has `|| true`, and installs an unpinned
  kustomize. The new workflow supersedes it.
- [ ] Add server-side dry-run to CI once a safe, read-only cluster credential
  exists.

### Secrets

- [ ] Seal the remaining plaintext secrets and delete the working copies.
- [ ] Back up the Sealed Secrets controller key offline.
- [ ] Confirm the misnamed `cluster-sealed-secrets-master.key` is stored
  securely and never committed.

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
