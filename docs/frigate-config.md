# Frigate configuration in Git

Status: active. The full Frigate camera configuration is maintained in this
repository under `applications/apps/frigate/manifests/config/`. The pod copies it onto
the config PVC at every start, so Git is the source of truth.

## What is managed in Git

| Path | Purpose |
|---|---|
| `applications/apps/frigate/manifests/config/config.yaml.tpl` | Complete Frigate `config.yaml` (cameras, go2rtc, record, MQTT, objects) |
| `applications/apps/frigate/manifests/kustomization.yaml` | `configMapGenerator` publishing the template as ConfigMap `frigate-git-config` |
| `applications/apps/frigate/manifests/deployment.yaml` | `sync-config` init container and volumes |
| `applications/apps/frigate/manifests/frigate-secrets-sealed-secret.yaml` | SealedSecret `frigate-secrets` with MQTT and per-camera RTSP credentials |

The `.tpl` extension is deliberate: repository validation treats every
`applications/**/*.yaml` file as a Kubernetes manifest, and this file is not
one. The kustomize generator publishes it to the ConfigMap under the key
`config.yaml`.

## How it reaches the pod

1. Kustomize builds ConfigMap `frigate-git-config-<content-hash>` from
   `config/config.yaml.tpl` and rewrites the Deployment's volume reference to
   the hashed name. Because the pod template changes, Argo rolls the Deployment
   automatically when the config changes.
2. Init container `restore-config` runs first and still restores
   `/backup/migration/frigate-config.tgz` **once**, guarded by
   `/config/.restored-from-nas`. It is kept for the rest of the PVC contents
   (`frigate.db`, `model_cache`); it no longer owns `config.yaml` long term.
3. Init container `sync-config` runs next. It writes the rendered ConfigMap key
   to `/config/.config.yaml.tmp`, fsyncs it, then `os.replace()`s it over
   `/config/config.yaml` (atomic on the same filesystem). If the content
   changed, the previous file is kept as `/config/config.yaml.bak`.
4. `sync-config` only touches `config.yaml`. `frigate.db`,
   `frigate.db-wal`, `model_cache/`, and `/media/frigate` recordings are not
   modified.

`{FRIGATE_*}` placeholders are **expected** to remain in
`/config/config.yaml` on the PVC. Frigate substitutes them at config load time
from environment variables. Those variables come from the `frigate-secrets`
Secret via `envFrom` on the `frigate` container.

## Git flow

```bash
$EDITOR applications/apps/frigate/manifests/config/config.yaml.tpl
make validate
git add applications/apps/frigate docs/frigate-config.md
git commit -m "feat(frigate): ..."
git push origin main
```

Argo CD auto-syncs the `frigate` Application. A ConfigMap content change
changes the pod template hash, so the Deployment rolls automatically. If the
rollout does not happen (for example only a Secret changed), restart it:

```bash
kubectl -n frigate rollout restart deploy/frigate
kubectl -n frigate rollout status deploy/frigate --timeout=5m
```

Do not edit `/config/config.yaml` from inside the pod as a long-term change:
the next pod start overwrites it from Git.

## Adding a camera

The existing pattern uses one go2rtc restream per camera and one Frigate camera
that reads from `127.0.0.1:8554`.

1. Add the stream under `go2rtc.streams`:

   ```yaml
   go2rtc:
     streams:
       garage:
         - rtsp://{FRIGATE_GARAGE_CREDENTIALS}@192.168.68.90/live0
   ```

2. Add the camera block under `cameras:`, matching the existing attic entries:

   ```yaml
   cameras:
     garage:
       ffmpeg:
         output_args:
           record: preset-record-generic-audio-copy
         inputs:
           - path: rtsp://127.0.0.1:8554/garage
             input_args: preset-rtsp-restream
             roles:
               - record
               - detect
       detect:
         width: 2560
         height: 1440
   ```

3. Add the credential to the SealedSecret (see below) and redeploy.

Camera credentials are per camera
(`FRIGATE_ATTIC1_CREDENTIALS` ... `FRIGATE_ATTIC4_CREDENTIALS`). Keep that
pattern: a single shared `FRIGATE_RTSP_PASSWORD` only works if every camera
uses the same username and password. Per-camera variables avoid coupling and
let one camera be rotated without touching the rest.

## Secret handling

Nothing plaintext is committed. The credential format is `username:password`,
URL-encoded as needed for use in the RTSP URL, and Frigate substitutes the
whole `{FRIGATE_*}` token.

To add or rotate a value, create a temporary Secret manifest locally, seal it
with the cluster's public certificate, and commit only the SealedSecret:

```bash
kubectl -n frigate create secret generic frigate-secrets \
  --from-literal=FRIGATE_GARAGE_CREDENTIALS='user:password' \
  --dry-run=client -o yaml > /tmp/frigate-secret.yaml

kubeseal --controller-name sealed-secrets-controller \
  --controller-namespace kube-system \
  --format yaml < /tmp/frigate-secret.yaml > /tmp/frigate-sealed.yaml

rm /tmp/frigate-secret.yaml
```

Merge the resulting `encryptedData` key into
`frigate-secrets-sealed-secret.yaml` (or seal the complete Secret again so all
keys stay in one object). Do not replace the file with a partial SealedSecret:
SealedSecret keys are merged, but keeping the full object in Git makes review
and rotation predictable.

Never commit the temporary plaintext Secret. `make validate` runs gitleaks; the
only allowlisted manifests are `*-sealed-secret.yaml` files, whose payload is
encrypted.

## Verify after a change

```bash
# Rollout and init container logs
kubectl -n frigate rollout status deploy/frigate --timeout=5m
kubectl -n frigate logs deploy/frigate -c sync-config

# File on the PVC matches the Git template (placeholders still present)
cm=$(kubectl -n frigate get configmap -o name | grep frigate-git-config | head -n1)
kubectl -n frigate get "$cm" \
  -o jsonpath='{.data.config\.yaml}' > /tmp/frigate-config.git.yaml
kubectl -n frigate exec deploy/frigate -c frigate -- \
  cat /config/config.yaml > /tmp/frigate-config.pvc.yaml
diff -u /tmp/frigate-config.git.yaml /tmp/frigate-config.pvc.yaml

# Cameras and go2rtc streams loaded
kubectl -n frigate exec deploy/frigate -c frigate -- sh -c \
  'wget -qO- http://127.0.0.1:5000/api/config' \
  | python3 -c 'import json,sys; print(sorted(json.load(sys.stdin)["cameras"]))'
kubectl -n frigate exec deploy/frigate -c frigate -- sh -c \
  'wget -qO- http://127.0.0.1:1984/api/streams' \
  | python3 -c 'import json,sys; print(sorted(json.load(sys.stdin)))'
```

Also check the logs for `ffmpeg.<camera>` errors and confirm MQTT/Home
Assistant discovery still shows all cameras. A camera whose network path is
down will show `no route to host` or `404 Not Found`; that is a camera/network
problem, not a config-sync problem.

## What stays on the PVC

| Path | Owner |
|---|---|
| `/config/frigate.db` (plus `-wal`/`-shm`) | Frigate runtime database |
| `/config/model_cache/` | Frigate model downloads |
| `/config/config.yaml.bak` | Last pre-sync config, for rollback |
| `/config/.restored-from-nas` | One-time NAS restore marker |
| `/media/frigate/` | Recordings on NFS (`192.168.68.138:/volume1/k8s-nfs/frigate-media`) |

None of these belong in Git. Recordings and the database are runtime state, and
the model cache is large and reproducible.
