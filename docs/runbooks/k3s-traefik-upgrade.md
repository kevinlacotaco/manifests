# k3s + Traefik upgrade runbook

> **Tailored to the current three-node cluster.**
> This upgrades **k3s `v1.31.4+k3s1` → `v1.31.14+k3s1` → `v1.32.13+k3s1`**, which moves Traefik from **2.11.10 → 2.11.24 → 3.6.9**.
>
> It does **not** jump to the latest k3s, does **not** add control-plane HA, and does **not** migrate the datastore.
>
> This repository is public. Placeholders such as `<your-domain>`, `<nas-ip>`, and `<node-ip>` are intentional. Keep a filled-in copy in your private ops notes; do not commit private addresses or secrets.

---

## 0. At a glance

| Stage | Change | Cluster risk | Expected disruption | Rollback point |
|---|---|---|---|---|
| 1 | k3s `1.31.4` → `1.31.14`; Traefik `2.11.10` → `2.11.24` | Low | Brief API/Argo outage during `boulder`; brief NotReady during agent restarts | Pre-stage SQLite backup + old binary |
| 2 | Prepare Traefik v3 syntax changes | None | None | Git branch only |
| 3 | k3s `1.31.14` → `1.32.13`; Traefik `2.11.24` → `3.6.9` | High | Same as stage 1, plus Traefik v3 rollout and hauler ingress/DNS/Argo blip | Pre-stage SQLite backup + `1.31.14` binary |
| 4 | Validate, resume Argo, soak | Low | None planned | Roll back to stage 3 backup if needed |

**Recommended order:** `boulder` → `grapple` → `hauler`.

`hauler` is last because it hosts the only Traefik pod, the only CoreDNS pod, and the Argo server. If it has a problem, the server and the low-risk agent are already on the new version.

**You may stop after stage 1.** That is a complete, stable state. Do stage 3 on a separate day if that is less stressful.

---

## 1. Scope and expected impact

### What this runbook covers

- Patching k3s within 1.31.
- Preparing the two known Traefik v3 syntax changes.
- Upgrading k3s from 1.31 to 1.32, which bundles Traefik v3.6.9.
- Validation and rollback.

### What it does not cover

- k3s 1.33/1.34 or chart v40 changes.
- Three control planes, a VIP, or etcd HA.
- Migrating from SQLite to Postgres/etcd.
- Moving Traefik out of the k3s addon into an Argo-managed Helm release.

### Expected disruption

| Node | What happens | Expected impact |
|---|---|---|
| `boulder` | k3s server stops/restarts | Kubernetes API, `kubectl`, and Argo reconciliation are unavailable for roughly 1–3 minutes. Existing pods keep running. Ingress from the Traefik pod on `hauler` continues using its last configuration. |
| `grapple` | k3s agent stops/restarts | Node goes `NotReady` briefly. Existing radio pods keep running. No ingress impact. |
| `hauler` | k3s agent stops/restarts | Node goes `NotReady` briefly. Traefik, CoreDNS, and the Argo server may restart. Expect a short ingress/DNS/Argo UI blip. |

### Why there are no drains

**Do not run `kubectl drain` on any node.**

- `boulder` runs many controllers and stateful workloads.
- `hauler` runs the only Traefik, the only CoreDNS, and the Argo server.
- `grapple` runs radio workloads pinned by labels and taints; they cannot move to another node.

K3s binary replacement stops the k3s service without a drain. Container processes may continue briefly through the runtime, but the node's Kubernetes control plane and networking are unavailable during the restart, so do not treat this as zero-downtime. Draining would additionally evict the single-instance workloads and turn a short blip into a guaranteed outage.

### Why binary replacement instead of the install script

The install script rewrites the systemd unit and environment file using only the arguments and variables you pass. That would risk dropping:

- `hauler`'s `--node-ip` and `--flannel-iface`.
- `grapple`'s radio labels and `NoSchedule` taint.
- The existing agent token and server URL.

Replacing `/usr/local/bin/k3s` preserves the exact systemd units. Keep the old binary on every node for rollback.

---

## 2. Hard rules

Read these before touching a node.

- [ ] **No `kubectl drain`** on any node.
- [ ] **No install script** (`curl … | sh`); use binary replacement.
- [ ] **No `stable` channel** and no System Upgrade Controller for this jump.
- [ ] **No skipping minors**: 1.31 → 1.32, not 1.31 → 1.33.
- [ ] **No v3-only fields** while still on Traefik 2.11.
- [ ] **Do not merge the v3 syntax branch early.**
- [ ] **Do not delete old Traefik CRDs** before v3 is stable.
- [ ] **Do not delete old binaries or backups** until the upgrade has soaked.
- [ ] **Do not print tokens, private keys, or Secret values.**
- [ ] **One node at a time.** Validate before continuing.
- [ ] **Keep an SSH session open** on the node you are upgrading.
- [ ] **Fresh verified backup** before each stage.

---

## 3. Pre-flight

Run these from a workstation with admin kubeconfig, or from `boulder` with `sudo k3s kubectl`.

### 3.1 Access and baseline

- [ ] You can SSH to `boulder`, `hauler`, and `grapple` directly, independent of Kubernetes.
- [ ] You have passwordless `sudo` on all three.
- [ ] You know how to reach the NAS backup share.
- [ ] You have the k3s agent token stored securely; **do not print it**.
- [ ] You have a second terminal open to `hauler` for the duration of the window.

```bash
ssh <user>@boulder
ssh <user>@hauler
ssh <user>@grapple
```

### 3.2 Record current versions

```bash
kubectl get nodes -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,OS:.status.nodeInfo.osImage
```

On each node:

```bash
k3s --version
uname -m
```

Expected:

- All nodes: `v1.31.4+k3s1`
- `boulder` and `hauler`: `x86_64`
- `grapple`: `aarch64`

Record the output in the change note.

### 3.3 Confirm critical placement

```bash
kubectl -n kube-system get pods -o wide | grep -E 'traefik|coredns'
kubectl get pods -A -o wide | grep -E 'traefik|coredns|argocd-server|argocd-application-controller'
```

Expected:

- Traefik: one pod on `hauler`.
- CoreDNS: one pod on `hauler`.
- Argo server/controller: on `hauler`.

If this is different, stop and adjust the order. The runbook assumes `hauler` is the critical node.

### 3.4 Confirm addon ownership and versions

```bash
kubectl -n kube-system get helmchart traefik traefik-crd -o wide
kubectl -n kube-system get helmchartconfig traefik -o yaml
kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n kube-system get svc traefik -o wide
```

Expected:

- `traefik` image: `rancher/mirrored-library-traefik:2.11.10`
- `traefik` Service ports: `1883:30330`, `80:32647`, `443:30222`
- No `8080` Service port.

### 3.5 Baseline health

- [ ] Argo root `applications` and all child apps are `Synced/Healthy`.
- [ ] Traefik dashboard returns `401` with valid TLS.
- [ ] Argo CD UI/CLI works.
- [ ] Grafana, Homepage, Jellyfin, Home Assistant, Authelia, ntfy, and Uptime Kuma load.
- [ ] MQTT port answers.
- [ ] Prometheus targets are all `UP`.
- [ ] CoreDNS resolves cluster and LAN names.
- [ ] TLS certificate is the trusted wildcard.

```bash
kubectl -n argocd get applications
curl -sI https://traefik.<your-domain>/dashboard/ | head -1
curl -sI https://argocd.<your-domain>/ | head -1
nc -vz <hauler-ip> 30330
```

Expected `401`/`200`/`302` are fine. Any `5xx` is a baseline problem; fix it before upgrading.

### 3.6 Disk, time, and backup target

On each node:

```bash
df -h /var/lib/rancher /var/lib/containerd
timedatectl
```

On the NAS or a machine with the share mounted:

```bash
df -h /volume1/k8s-nfs
ls -lh /volume1/k8s-nfs/k3s-backups
```

- [ ] At least 10 GB free on each node.
- [ ] NTP is synchronized.
- [ ] The backup share is writable.
- [ ] The previous verified backup `k3s-state-20261125T1506Z.db` is present.

---

## 4. Freeze and backup

### 4.1 Pause Argo root auto-sync

Capture the exact policy before changing it:

```bash
kubectl -n argocd get application applications -o jsonpath='{.spec.syncPolicy}' \
  | tee /tmp/argo-applications-syncpolicy.json
```

Pause it:

```bash
kubectl -n argocd patch application applications --type=json \
  -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
```

Verify:

```bash
kubectl -n argocd get application applications -o jsonpath='{.spec.syncPolicy}{"\n"}'
```

Expected: no `automated` block.

> If it is already paused, skip the patch but still save the current policy.
> Argo may report `OutOfSync` while paused. That is expected.

### 4.2 Take a fresh SQLite backup

The cluster uses SQLite at `/var/lib/rancher/k3s/server/db/state.db`, not etcd. Do **not** use `k3s etcd-snapshot`.

Use the backup pod manifest in [Appendix A](#appendix-a-sqlite-backup-pod). Apply it from a workstation:

```bash
kubectl apply -f /tmp/k3s-sqlite-backup.yaml
kubectl logs -f pod/k3s-sqlite-backup
kubectl get pod k3s-sqlite-backup
kubectl delete pod k3s-sqlite-backup
```

Record:

- [ ] Backup filename
- [ ] Size
- [ ] SHA256
- [ ] `PRAGMA integrity_check` = `ok`
- [ ] Timestamp in UTC

Copy the backup filename and SHA into the change note.

> The backup is cluster state only. Application data on PVCs/NFS is separate and is not in `state.db`.

### 4.3 Back up cluster configuration

```bash
BACKUP=/tmp/k3s-upgrade-$(date -u +%Y%m%dT%H%MZ)
mkdir -p "$BACKUP"

kubectl -n kube-system get helmchart traefik traefik-crd -o yaml > "$BACKUP/helmcharts.yaml"
kubectl -n kube-system get helmchartconfig traefik -o yaml > "$BACKUP/helmchartconfig.yaml"
kubectl get ingressroute,middleware,ingressroutetcp -A -o yaml > "$BACKUP/traefik-resources.yaml"
kubectl get ingress -A -o yaml > "$BACKUP/ingresses.yaml"
kubectl -n kube-system get svc traefik -o yaml > "$BACKUP/traefik-service.yaml"
kubectl -n kube-system get deploy traefik -o yaml > "$BACKUP/traefik-deployment.yaml"
kubectl -n argocd get application applications -o yaml > "$BACKUP/argo-applications.yaml"
```

Copy that directory to the NAS backup share.

### 4.4 Back up host units and server credentials

Run on each node. The tarball contains tokens and keys; store it with mode `600`, do not commit it, and do not print it.

```bash
sudo tar --ignore-failed-read -C / -czf /tmp/k3s-host-$(hostname)-$(date -u +%Y%m%dT%H%MZ).tgz \
  var/lib/rancher/k3s/server/tls \
  var/lib/rancher/k3s/server/cred \
  var/lib/rancher/k3s/server/manifests \
  etc/systemd/system/k3s.service \
  etc/systemd/system/k3s.service.env \
  etc/systemd/system/k3s-agent.service \
  etc/systemd/system/k3s-agent.service.env
sudo chmod 600 /tmp/k3s-host-*.tgz
```

Copy the tarball to the NAS. Do not open it in a shared terminal.

### 4.5 Save the current binary on every node

Do this **before** stopping anything:

```bash
sudo cp -a /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.4
sha256sum /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.4
```

The two hashes must match. Keep `k3s.v1.31.4` until the whole upgrade is stable.

### 4.6 Freeze checklist

- [ ] Argo root auto-sync paused.
- [ ] Fresh SQLite backup verified.
- [ ] Cluster config backed up.
- [ ] Host units/credentials backed up.
- [ ] Old binary saved on all three nodes.
- [ ] No Git pushes or manual Kubernetes changes during the stage.
- [ ] Change window start time recorded.

---

## 5. Stage 1: k3s 1.31.4 → 1.31.14

This stage is intentionally low-risk: same Kubernetes minor, same Traefik major.

### 5.1 Download and verify the binary

On `boulder` and `hauler` (amd64):

```bash
cd /tmp
curl -fsSLo k3s-v1.31.14 \
  'https://github.com/k3s-io/k3s/releases/download/v1.31.14%2Bk3s1/k3s'
curl -fsSLo k3s-v1.31.14.sha256 \
  'https://github.com/k3s-io/k3s/releases/download/v1.31.14%2Bk3s1/sha256sum-amd64.txt'

EXPECTED=$(awk '$2=="k3s" {print $1}' k3s-v1.31.14.sha256)
ACTUAL=$(sha256sum k3s-v1.31.14 | awk '{print $1}')
test "$EXPECTED" = "$ACTUAL" && echo "checksum OK"
```

On `grapple` (arm64):

```bash
cd /tmp
curl -fsSLo k3s-v1.31.14 \
  'https://github.com/k3s-io/k3s/releases/download/v1.31.14%2Bk3s1/k3s-arm64'
curl -fsSLo k3s-v1.31.14.sha256 \
  'https://github.com/k3s-io/k3s/releases/download/v1.31.14%2Bk3s1/sha256sum-arm64.txt'

EXPECTED=$(awk '$2=="k3s-arm64" {print $1}' k3s-v1.31.14.sha256)
ACTUAL=$(sha256sum k3s-v1.31.14 | awk '{print $1}')
test "$EXPECTED" = "$ACTUAL" && echo "checksum OK"
```

Do not continue if the checksum fails.

### 5.2 Upgrade `boulder` first

```bash
sudo install -m 0755 /tmp/k3s-v1.31.14 /usr/local/bin/k3s.new
sudo systemctl stop k3s
sudo systemctl is-active k3s || true

sudo cp -a /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.4
sudo mv /usr/local/bin/k3s.new /usr/local/bin/k3s

sudo systemctl start k3s
```

Watch the service:

```bash
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 100 --no-pager
k3s --version
```

Expected: `v1.31.14+k3s1`.

From a workstation or from `boulder` after the API returns:

```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide | grep -E 'traefik|coredns'
```

Wait for `boulder` to be `Ready`. Do not touch the agents yet.

### 5.3 Upgrade `grapple` second

```bash
sudo install -m 0755 /tmp/k3s-v1.31.14 /usr/local/bin/k3s.new
sudo systemctl stop k3s-agent
sudo systemctl is-active k3s-agent || true

sudo cp -a /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.4
sudo mv /usr/local/bin/k3s.new /usr/local/bin/k3s

sudo systemctl start k3s-agent
```

```bash
sudo systemctl status k3s-agent --no-pager
sudo journalctl -u k3s-agent -n 100 --no-pager
k3s --version
```

Wait for `grapple` to be `Ready`. The radio pods should still be running.

### 5.4 Upgrade `hauler` last

```bash
sudo install -m 0755 /tmp/k3s-v1.31.14 /usr/local/bin/k3s.new
sudo systemctl stop k3s-agent
sudo systemctl is-active k3s-agent || true

sudo cp -a /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.4
sudo mv /usr/local/bin/k3s.new /usr/local/bin/k3s

sudo systemctl start k3s-agent
```

```bash
sudo systemctl status k3s-agent --no-pager
sudo journalctl -u k3s-agent -n 100 --no-pager
k3s --version
```

Expect a short ingress/DNS/Argo blip while Traefik/CoreDNS/Argo restart.

Wait for:

```bash
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide | grep -E 'traefik|coredns'
kubectl -n argocd get pods
```

### 5.5 Stage 1 validation

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion
kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik -o wide
kubectl -n argocd get applications
```

Expected:

- All nodes `v1.31.14+k3s1`.
- Traefik image `rancher/mirrored-library-traefik:2.11.24`.
- Traefik `1/1`.
- CoreDNS `1/1`.
- Argo apps healthy (may be `OutOfSync` because auto-sync is paused).

Run the URL/TLS/MQTT/DNS checklist in [Appendix C](#appendix-c-url-and-service-checklist). If anything fails, roll back stage 1 before proceeding.

### 5.6 Resume Argo after stage 1

```bash
POLICY=$(cat /tmp/argo-applications-syncpolicy.json)
kubectl -n argocd patch application applications --type=merge \
  -p "{\"spec\":{\"syncPolicy\":$POLICY}}"

kubectl -n argocd annotate application applications \
  argocd.argoproj.io/refresh=hard --overwrite

kubectl -n argocd get applications
```

Wait for `Synced/Healthy`. If the patch is awkward, use the explicit fallback:

```bash
kubectl -n argocd patch application applications --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true"]}}}'
```

### 5.7 Take the pre-stage-3 backup

After stage 1 is stable and Argo is healthy:

1. Pause Argo again using section 4.1.
2. Take another fresh SQLite backup using section 4.2.
3. Save the current binary on all nodes as `k3s.v1.31.14`:

```bash
sudo cp -a /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.14
sha256sum /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.14
```

This backup and binary are the rollback point for stage 3.

---

## 6. Stage 2: prepare Traefik v3 syntax changes

Do this in Git only. Do not apply it while Traefik 2.11 is running.

### 6.1 Create the branch

```bash
git checkout main
git pull --ff-only
git checkout -b upgrade/traefik-v3
```

### 6.2 Change the dashboard allowlist

In `applications/platform/traefik/dashboard.yaml`:

```diff
-    ipWhiteList:
+    ipAllowList:
       sourceRange:
         - <lan-subnet>
         - <pod-subnet>
```

Traefik v3 renamed `IPWhiteList` to `IPAllowList`. Do not change the existing `sourceRange` entries; they are shown as placeholders here.

### 6.3 Change the Argo gRPC matcher

In `applications/platform/argocd/ingress.yaml`:

```diff
-  match: Host(`argocd.<your-domain>`) && Headers(`Content-Type`, `application/grpc`)
+  match: Host(`argocd.<your-domain>`) && Header(`Content-Type`, `application/grpc`)
```

Traefik v3 renamed the `Headers` matcher to `Header`.

### 6.4 Validate and commit

```bash
kubectl kustomize applications/platform/traefik > /tmp/traefik-v3.yaml
kubectl kustomize applications/platform/argocd > /tmp/argocd-v3.yaml
python3 - <<'PY'
import yaml
for p in ('/tmp/traefik-v3.yaml', '/tmp/argocd-v3.yaml'):
    list(yaml.safe_load_all(open(p)))
    print('ok', p)
PY
git diff --check
git add applications/platform/traefik/dashboard.yaml applications/platform/argocd/ingress.yaml
git commit -m "chore(traefik): prepare v3 route syntax"
```

**Do not merge or push this branch to `main` yet.** It is v3-only syntax.

### 6.5 Plugin review

Current plugins:

- CrowdSec bouncer: `v1.8.2`
- Geoblock: `v0.3.8`

Both are Yaegi plugins. They have no Traefik dependency in their `go.mod`, but that does not guarantee v3 runtime compatibility. Before stage 3:

- [ ] Review their release notes for Traefik v3 support.
- [ ] Prefer testing them in a throwaway Traefik v3 instance or staging cluster.
- [ ] If updating a plugin, do it in this branch and make it a separate, reversible change.
- [ ] If a plugin is known to be incompatible, stop. Do not upgrade.

If you skip the plugin canary, the stage 3 rollout is the test. Have the rollback ready.

---

## 7. Stage 3: k3s 1.31.14 → 1.32.13

This is the major jump. It moves Traefik to **3.6.9**.

### 7.1 Freeze and confirm the rollback point

- [ ] Argo root auto-sync is paused.
- [ ] The pre-stage-3 SQLite backup is verified.
- [ ] `k3s.v1.31.14` exists on all three nodes.
- [ ] The stage 2 branch is committed locally and not merged.
- [ ] No one is applying Git or Kubernetes changes.

### 7.2 Download and verify 1.32.13

On `boulder` and `hauler` (amd64):

```bash
cd /tmp
curl -fsSLo k3s-v1.32.13 \
  'https://github.com/k3s-io/k3s/releases/download/v1.32.13%2Bk3s1/k3s'
curl -fsSLo k3s-v1.32.13.sha256 \
  'https://github.com/k3s-io/k3s/releases/download/v1.32.13%2Bk3s1/sha256sum-amd64.txt'

EXPECTED=$(awk '$2=="k3s" {print $1}' k3s-v1.32.13.sha256)
ACTUAL=$(sha256sum k3s-v1.32.13 | awk '{print $1}')
test "$EXPECTED" = "$ACTUAL" && echo "checksum OK"
```

On `grapple` (arm64):

```bash
cd /tmp
curl -fsSLo k3s-v1.32.13 \
  'https://github.com/k3s-io/k3s/releases/download/v1.32.13%2Bk3s1/k3s-arm64'
curl -fsSLo k3s-v1.32.13.sha256 \
  'https://github.com/k3s-io/k3s/releases/download/v1.32.13%2Bk3s1/sha256sum-arm64.txt'

EXPECTED=$(awk '$2=="k3s-arm64" {print $1}' k3s-v1.32.13.sha256)
ACTUAL=$(sha256sum k3s-v1.32.13 | awk '{print $1}')
test "$EXPECTED" = "$ACTUAL" && echo "checksum OK"
```

### 7.3 Upgrade `boulder` first

```bash
sudo install -m 0755 /tmp/k3s-v1.32.13 /usr/local/bin/k3s.new
sudo systemctl stop k3s
sudo systemctl is-active k3s || true

sudo cp -a /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.14
sudo mv /usr/local/bin/k3s.new /usr/local/bin/k3s

sudo systemctl start k3s
```

```bash
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 150 --no-pager
k3s --version
```

Expected: `v1.32.13+k3s1`.

Wait for the API and then watch the addon update:

```bash
kubectl get nodes -o wide
kubectl -n kube-system get helmchart traefik traefik-crd -o wide
kubectl -n kube-system get pods -o wide | grep -E 'traefik|coredns|helm'
kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Expected after the addon rolls:

- Traefik image `rancher/mirrored-library-traefik:3.6.9`.
- Traefik pod `1/1` on `hauler`.
- CoreDNS `1/1` (or more, if you have scaled it separately).

At this point the server is 1.32 and the agents are still 1.31.14. That is within supported skew. Do not upgrade the agents until the API and Traefik v3 are stable.

Check Traefik startup:

```bash
kubectl -n kube-system logs deploy/traefik --tail=200 \
  | grep -Ei 'error|plugin|crowdsec|geoblock|panic'
```

No plugin/startup errors.

### 7.4 Upgrade `grapple` second

```bash
sudo install -m 0755 /tmp/k3s-v1.32.13 /usr/local/bin/k3s.new
sudo systemctl stop k3s-agent
sudo systemctl is-active k3s-agent || true

sudo cp -a /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.14
sudo mv /usr/local/bin/k3s.new /usr/local/bin/k3s

sudo systemctl start k3s-agent
```

```bash
sudo systemctl status k3s-agent --no-pager
sudo journalctl -u k3s-agent -n 100 --no-pager
k3s --version
```

Wait for `grapple` `Ready`; confirm radio pods are still running.

### 7.5 Upgrade `hauler` last

```bash
sudo install -m 0755 /tmp/k3s-v1.32.13 /usr/local/bin/k3s.new
sudo systemctl stop k3s-agent
sudo systemctl is-active k3s-agent || true

sudo cp -a /usr/local/bin/k3s /usr/local/bin/k3s.v1.31.14
sudo mv /usr/local/bin/k3s.new /usr/local/bin/k3s

sudo systemctl start k3s-agent
```

```bash
sudo systemctl status k3s-agent --no-pager
sudo journalctl -u k3s-agent -n 100 --no-pager
k3s --version
```

Expect a short ingress/DNS/Argo blip. Wait for:

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion
kubectl -n kube-system get pods -o wide | grep -E 'traefik|coredns'
kubectl -n argocd get pods
```

All nodes should now be `v1.32.13+k3s1`.

### 7.6 Apply the v3 syntax changes

Only now merge the prepared branch:

```bash
git checkout main
git merge --ff-only upgrade/traefik-v3
git push origin main
```

Resume Argo:

```bash
POLICY=$(cat /tmp/argo-applications-syncpolicy.json)
kubectl -n argocd patch application applications --type=merge \
  -p "{\"spec\":{\"syncPolicy\":$POLICY}}"

kubectl -n argocd annotate application applications \
  argocd.argoproj.io/refresh=hard --overwrite

kubectl -n argocd get applications
```

If Argo does not apply the two changes automatically, sync the root app:

```bash
argocd app sync applications
```

Verify the live resources:

```bash
kubectl -n kube-system get middleware traefik-dashboard-allowlist -o yaml | grep -E 'ipAllowList|ipWhiteList'
kubectl -n argocd get ingressroute argocd-lakotko -o yaml | grep -E 'Header|Headers'
```

Expected: `ipAllowList` and `Header`.

### 7.7 Temporary v2 syntax fallback

Use this only if a route still fails after the two known changes:

```yaml
# applications/platform/traefik/entry-points.yaml
additionalArguments:
  # keep all existing arguments
  - --core.defaultRuleSyntax=v2
```

Commit it, let Argo sync, and confirm Traefik restarts. Then fix the route and remove the flag.

**Do not leave `defaultRuleSyntax=v2` in place permanently.** It is a temporary compatibility bridge.

### 7.8 Stage 3 validation

Run the full checklist in section 8.

---

## 8. Post-upgrade validation

### 8.1 Versions and control plane

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion
kubectl -n kube-system get pods -o wide | grep -E 'traefik|coredns'
kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Expected:

- All nodes `v1.32.13+k3s1`
- Traefik `3.6.9`
- Traefik `1/1`
- CoreDNS `1/1`

### 8.2 Argo

```bash
kubectl -n argocd get applications
```

Expected: all `Synced/Healthy`. If the root app is `OutOfSync`, hard-refresh and check the operation message.

### 8.3 Traefik dashboard and gRPC

```bash
curl -sI https://traefik.<your-domain>/dashboard/ | head -1
curl -sI https://argocd.<your-domain>/ | head -1
argocd app list
```

Expected:

- Traefik dashboard: `401` with valid TLS.
- Argo: `200`/`302`.
- `argocd app list` works; this proves the gRPC route is healthy.

### 8.4 Applications

Run the URL checklist in [Appendix C](#appendix-c-url-and-service-checklist).

Any `5xx` is a failure. A `401`/`302` from an auth-protected app is normal.

### 8.5 TLS

```bash
curl -sI https://grafana.<your-domain>/ | head -1
curl -sI https://homepage.<your-domain>/ | head -1
curl -sI https://jellyfin.<your-domain>/ | head -1
```

Do **not** use `-k` here. The wildcard should verify without it.

Also check the TLS sync CronJobs:

```bash
kubectl -n kube-system get cronjob traefik-tls-sync
kubectl -n monitoring get cronjob grafana-tls-sync
kubectl -n networking get cronjob adguardhome-sync
```

### 8.6 MQTT

```bash
nc -vz <hauler-ip> 30330
```

If you have a test MQTT client and credentials, publish/subscribe to a test topic. The TCP listener is the important part; the `HostSNI(*)` route should be unchanged.

### 8.7 DNS

```bash
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local
```

Expected: server `10.43.0.10` and an address.

Also test a LAN name from a workstation:

```bash
nslookup grafana.<your-domain>
```

### 8.8 Prometheus

Open Prometheus **Status → Targets**, or:

```bash
kubectl -n monitoring port-forward svc/prometheus-server 9090:80
# in another terminal:
curl -s 'http://127.0.0.1:9090/api/v1/targets?state=active' \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(1 for t in d["data"]["activeTargets"] if t["health"]!="up"), "down")'
```

Expected: `0 down`.

Traefik v3 changes some metric names; the target should still be `UP`. If a dashboard panel goes blank, that is a metric-name issue, not necessarily a scrape failure.

### 8.9 CrowdSec and geoblock

```bash
kubectl -n kube-system logs deploy/traefik --tail=300 \
  | grep -Ei 'plugin|yaegi|crowdsec|geoblock|error|panic'
```

No plugin/startup errors. Test a normal ingress request and, if practical, a request that should be blocked.

### 8.10 Soak

- [ ] Watch for 24 hours.
- [ ] No Traefik restarts.
- [ ] No Argo drift.
- [ ] Prometheus targets stay `UP`.
- [ ] Certificates renew through the existing sync jobs.
- [ ] MQTT clients reconnect and stay connected.

### 8.11 Optional: restore Jellyfin PNA support

Traefik v3 supports the native Private Network Access header. After the upgrade is stable, you can re-add this to the Jellyfin CORS middleware as a separate change:

```yaml
accessControlAllowPrivateNetwork: true
```

Then verify the preflight:

```bash
curl -skI -X OPTIONS https://jellyfin.<your-domain>/health \
  -H 'Origin: https://ha.<your-domain>' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Private-Network: true'
```

Expected: `access-control-allow-private-network: true`.

This was removed earlier because Traefik 2.11 did not support it.

---

## 9. Rollback

### 9.1 Decision table

| Symptom | Action |
|---|---|
| Stage 1 fails on a node | Restore that node's `k3s.v1.31.4` binary and restart. |
| Stage 1 API not ready >10 min | Restore `boulder` binary and the pre-stage backup. |
| Stage 3 Traefik v3 CrashLoop/plugin error | Full stage 3 rollback: all nodes back to `1.31.14`, restore pre-stage-3 SQLite backup. |
| Stage 3 one route 404/401 due syntax | Apply the v3 branch, or temporarily add `defaultRuleSyntax=v2`. Do not roll back for this. |
| Stage 3 one agent NotReady >10 min | Restore that agent's `k3s.v1.31.14` binary. Server can stay 1.32. |
| Stage 3 `boulder` API not ready >10 min | Full stage 3 rollback. |
| TLS/502 on critical hosts and not fixed in 10–15 min | Full stage 3 rollback. |
| Data-loss signs | Stop and restore the appropriate SQLite backup. |

### 9.2 Quick binary rollback (patch stage)

On the affected node:

```bash
sudo systemctl stop k3s          # or k3s-agent
sudo install -m 0755 /usr/local/bin/k3s.v1.31.4 /usr/local/bin/k3s
sudo systemctl start k3s         # or k3s-agent
```

Verify:

```bash
k3s --version
kubectl get nodes -o wide
```

If the older binary cannot start against the datastore, restore the pre-stage SQLite backup.

### 9.3 Full stage 3 rollback

This is the reliable rollback when Traefik v3 or the 1.32 control plane is unhealthy.

Order:

1. Stop agents.
2. Stop the server.
3. Restore the old binaries on **all** nodes.
4. Restore the pre-stage-3 SQLite backup on `boulder`.
5. Start the server.
6. Start the agents.
7. Verify.
8. Keep Argo paused until healthy.

On `hauler` and `grapple`:

```bash
sudo systemctl stop k3s-agent
sudo install -m 0755 /usr/local/bin/k3s.v1.31.14 /usr/local/bin/k3s
# do not start yet
```

On `boulder`:

```bash
sudo systemctl stop k3s
sudo install -m 0755 /usr/local/bin/k3s.v1.31.14 /usr/local/bin/k3s
sudo install -m 0600 /volume1/k8s-nfs/k3s-backups/<pre-stage-3-backup>.db \
  /var/lib/rancher/k3s/server/db/state.db
sudo rm -f /var/lib/rancher/k3s/server/db/state.db-wal \
           /var/lib/rancher/k3s/server/db/state.db-shm
sudo systemctl start k3s
```

If the NAS path is not mounted directly on `boulder`, copy the backup there first. Do not print its contents.

Wait for the API, then start the agents:

```bash
# on hauler
sudo systemctl start k3s-agent

# on grapple
sudo systemctl start k3s-agent
```

Verify:

```bash
k3s --version
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide | grep -E 'traefik|coredns'
kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Expected after rollback: k3s `v1.31.14+k3s1` and Traefik `2.11.24`.

> If you need to go all the way back to `1.31.4`, use the pre-stage-1 backup and `k3s.v1.31.4` on all nodes.

### 9.4 Restore Argo

The restored SQLite backup may contain an enabled or disabled Argo policy depending on when it was taken. Because this runbook pauses Argo before backing up, it should be paused.

If it is enabled and you need to stop reconciliation:

```bash
kubectl -n argocd patch application applications --type=json \
  -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]'
```

When the cluster is healthy again, restore the saved policy from section 4.1.

### 9.5 After rollback

- [ ] All nodes `Ready`.
- [ ] Traefik `1/1` and expected image.
- [ ] CoreDNS `1/1`.
- [ ] Argo apps healthy.
- [ ] Critical URLs and TLS work.
- [ ] MQTT port works.
- [ ] Prometheus targets `UP`.
- [ ] Root cause understood before retrying.

Do not immediately retry the upgrade after a rollback. Capture logs first.

---

## 10. Stop conditions

Stop and roll back if any of these are true:

- Traefik is `CrashLoopBackOff` or logs a plugin/Yaegi panic.
- The API is not ready more than 10 minutes after `boulder` starts.
- A node is `NotReady` more than 10 minutes after its service starts.
- Traefik routes are broadly failing with `502`/`504`.
- TLS is broken on multiple critical hostnames.
- Argo gRPC is still broken after the `Header` change.
- CoreDNS is not ready and cluster DNS is failing.
- MQTT is down and not recovering.
- There are signs of datastore corruption or data loss.

Do not continue to the next node while a previous node is unhealthy.

---

## 11. Timeline

| Phase | Estimate |
|---|---|
| Pre-flight and baseline | 20–30 min |
| Freeze, backup, config backup | 20–30 min |
| Stage 1 (three nodes) | 20–30 min |
| Stage 1 validation and Argo resume | 15–20 min |
| Stage 2 branch preparation | 15–30 min |
| Stage 3 (three nodes) | 45–75 min |
| Stage 3 validation and Argo sync | 30–45 min |
| Buffer | 30 min |

Plan a **2–3 hour window** for stage 1 + stage 3, or split them across two days.

---

## Appendix A: SQLite backup pod

This is an online, consistent snapshot using SQLite `VACUUM INTO`. It does not stop k3s.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: k3s-sqlite-backup
  namespace: default
spec:
  restartPolicy: Never
  nodeName: boulder
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
  containers:
    - name: backup
      image: alpine:3.20
      securityContext:
        runAsUser: 0
      command:
        - /bin/sh
        - -ec
        - |
          apk add --no-cache sqlite
          TS=$(date -u +%Y%m%dT%H%MZ)
          OUT=/backup/k3s-state-$TS.db
          sqlite3 /source/state.db "VACUUM INTO '$OUT'"
          sqlite3 "$OUT" "PRAGMA integrity_check;"
          sha256sum "$OUT" > "$OUT.sha256"
          {
            echo "{"
            echo "  \"timestamp\": \"$TS\","
            echo "  \"source\": \"/var/lib/rancher/k3s/server/db/state.db\","
            echo "  \"bytes\": $(stat -c %s "$OUT"),"
            echo "  \"sha256\": \"$(cut -d' ' -f1 "$OUT.sha256")\""
            echo "}"
          } > "$OUT.json"
          chmod 600 "$OUT" "$OUT.sha256" "$OUT.json"
          ls -lh "$OUT"*
      volumeMounts:
        - name: source
          mountPath: /source
        - name: backup
          mountPath: /backup
  volumes:
    - name: source
      hostPath:
        path: /var/lib/rancher/k3s/server/db
        type: Directory
    - name: backup
      nfs:
        server: <nas-ip>
        path: /volume1/k8s-nfs/k3s-backups
```

Run:

```bash
kubectl apply -f /tmp/k3s-sqlite-backup.yaml
kubectl logs -f pod/k3s-sqlite-backup
kubectl delete pod k3s-sqlite-backup
```

If PodSecurity blocks the pod, run the same backup directly on `boulder` as root and copy the result to the NAS:

```bash
sudo apt-get install -y sqlite3   # only if sqlite3 is missing
TS=$(date -u +%Y%m%dT%H%MZ)
sudo sqlite3 /var/lib/rancher/k3s/server/db/state.db \
  "VACUUM INTO '/tmp/k3s-state-$TS.db'"
sudo sqlite3 /tmp/k3s-state-$TS.db "PRAGMA integrity_check;"
sudo sha256sum /tmp/k3s-state-$TS.db
```

Then copy `/tmp/k3s-state-$TS.db` to `/volume1/k8s-nfs/k3s-backups/`.

---

## Appendix B: version map

| k3s | Traefik | Notes |
|---|---|---|
| `v1.31.4+k3s1` | `2.11.10` | Current |
| `v1.31.14+k3s1` | `2.11.24` | Stage 1 |
| `v1.32.13+k3s1` | `3.6.9` | Stage 3 |
| `v1.33.13+k3s2` | `3.7.8` / chart v40 | Not this runbook |
| `v1.34.13+k3s1` | `3.7.15` / chart v40 | Later, separate upgrade |

Do not jump from 1.31 to 1.33. Kubernetes version skew requires one minor at a time.

---

## Appendix C: URL and service checklist

Replace `<your-domain>`. Use `curl -sI` without `-k` to test TLS.

| Check | Expected |
|---|---|
| `https://traefik.<your-domain>/dashboard/` | `401`, valid TLS |
| `https://argocd.<your-domain>/` | `200`/`302` |
| `https://grafana.<your-domain>/` | `302` to login |
| `https://homepage.<your-domain>/` | `200` |
| `https://jellyfin.<your-domain>/` | `302` |
| `https://ha.<your-domain>/` | `200`/`405` |
| `https://auth.<your-domain>/` | `200` |
| `https://ntfy.<your-domain>/` | `200` |
| `https://kuma.<your-domain>/` | `302` |
| `https://meals.<your-domain>/` | `302` |
| `https://tasks.<your-domain>/` | `302` |
| `https://git.<your-domain>/` | `200` |
| `https://paperless.<your-domain>/` | `302` |
| `https://youtarr.<your-domain>/` | `200` |
| `https://frigate.<your-domain>/` | `200` |

Also check:

- MQTT: `nc -vz <hauler-ip> 30330`
- CoreDNS: `nslookup kubernetes.default.svc.cluster.local`
- Prometheus: `0 down`
- Argo CLI: `argocd app list`
- Traefik logs: no plugin/panic/error

---

## Appendix D: why not the automated upgrade controller

The System Upgrade Controller is not installed, and it would not remove the significant risks:

- It does not back up SQLite.
- It does not validate Traefik plugins or v3 routes.
- It does not make the single control-plane API highly available.
- It does not make the single Traefik pod highly available.
- `channel: stable` can attempt to skip minors.
- There is no automatic rollback.

Use this manual, pinned runbook for the 1.31 → 1.32 Traefik v3 jump. If you later use the controller for patch-level upgrades, pin the exact version and keep it supervised.

---

## Appendix E: after the upgrade is stable

- [ ] Keep the pre-stage backups for at least 30 days.
- [ ] Keep `k3s.v1.31.14` and `k3s.v1.31.4` binaries for at least 14 days.
- [ ] Remove the temporary `defaultRuleSyntax=v2` flag if you used it.
- [ ] Update `README.md` and `TODO.md` with the new k3s/Traefik versions.
- [ ] Record the Traefik v3 metrics-name changes if a dashboard panel went blank.
- [ ] Plan k3s 1.33/1.34 and chart v40 as a separate upgrade.
- [ ] Consider two Traefik replicas with anti-affinity and a PodDisruptionBudget.
- [ ] Consider two CoreDNS replicas if DNS blips are unacceptable.
- [ ] Re-test the Jellyfin PNA header on Traefik v3 if you want HA media playback fixed.
