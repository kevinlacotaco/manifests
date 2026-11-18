# Jellyfin

Status: **running** (deployed 2026-11-18). This is the operator runbook for the
homelab Jellyfin instance.

## Access

- URL: <https://jellyfin.lakotko.synology.me>
- Internal service: `jellyfin.jellyfin.svc.cluster.local:8096`
- Namespace: `jellyfin`
- Argo CD application: `jellyfin`
- Manifests: `applications/apps/jellyfin/`

The Synology reverse proxy already forwards `jellyfin.lakotko.synology.me` to
Traefik, so no extra proxy rule is required. The route is **not** behind
Authelia forward-auth; Jellyfin uses its own accounts. The global CrowdSec
bouncer still applies at the Traefik entrypoint.

## What is deployed

| Item | Value |
|---|---|
| Image | `jellyfin/jellyfin:12.4` |
| Node | `boulder` (N100, best Quick Sync codec coverage) |
| Config | PVC `jellyfin-config`, 20 GiB, `synology-iscsi` |
| Cache/transcode | `emptyDir` mounted at `/cache` (8 GiB memory limit) |
| Media | NFS `192.168.68.138:/volume1/media`, mounted **read-only** at `/media` |
| Hardware transcode | hostPath `/dev/dri` (`card0`, `renderD128`), groups `44` and `993` |
| Service | ClusterIP, port `8096` |
| Ingress | `jellyfin.lakotko.synology.me`, Traefik |

Media folders on the NAS:

```text
/volume1/media/movies
/volume1/media/tv
/volume1/media/music
/volume1/media/photos
```

The share is exported read-only to `192.168.68.0/24`. Jellyfin can read media
but cannot modify or delete it.

## First-run checklist

1. Open <https://jellyfin.lakotko.synology.me>.
2. Create the first user. The first account becomes the administrator. Use a
   strong password and store it in your password manager.
3. Add libraries from **Dashboard -> Libraries -> Add Media Library**:

   | Library type | Folder |
   |---|---|
   | Movies | `/media/movies` |
   | Shows | `/media/tv` |
   | Music | `/media/music` |
   | Photos | `/media/photos` |

   Leave "Enable real-time monitoring" enabled if the NAS supports inotify for
   the mount; otherwise use a scheduled scan.
4. Set metadata language and country to your preference. Jellyfin needs
   outbound HTTPS for metadata; the pod NetworkPolicy allows `80`/`443`.
5. Open **Dashboard -> Playback -> Transcoding** and enable hardware
   transcoding:

   - Hardware acceleration: **Intel Quick Sync Video (QSV)**
   - Enable hardware decoding for H.264, HEVC, AV1, VP9, MPEG-2 and VC-1
     where listed.
   - Enable hardware encoding for H.264, HEVC and AV1 where listed.
   - Enable tone mapping if you play HDR content on SDR displays.
   - Set the transcode temporary path to `/cache/transcode`.
   - Save.

6. Create any additional users under **Dashboard -> Users**. Do not enable
   public registration.
7. Play a title and confirm it starts. While playing, open **Dashboard ->
   Activity** (or the logs) and check that the stream is transcoding with
   `h264_qsv` / `hevc_qsv` / `av1_qsv` rather than CPU `libx264`.

The `movies`, `tv`, `music` and `photos` folders are currently empty. Copy
media into `/volume1/media/...` on the NAS before expecting a populated
library.

## Verify from the cluster

```bash
kubectl -n jellyfin get pods -o wide
kubectl -n jellyfin get pvc
kubectl -n jellyfin exec deploy/jellyfin -- ls -l /dev/dri
kubectl -n jellyfin logs deploy/jellyfin | grep -iE 'qsv|vaapi|ffmpeg'
```

Expected: pod `Running` on `boulder`, PVC `Bound`, `/dev/dri/card0` and
`renderD128` present, and FFmpeg listing QSV encoders/decoders.

Health endpoint:

```bash
kubectl -n jellyfin port-forward svc/jellyfin 8096:8096
curl -fsS http://127.0.0.1:8096/health
```

## Operations

Restart:

```bash
kubectl -n jellyfin rollout restart deploy/jellyfin
kubectl -n jellyfin rollout status deploy/jellyfin --timeout=180s
```

Logs:

```bash
kubectl -n jellyfin logs deploy/jellyfin -f
```

Update the image: change the tag in
`applications/apps/jellyfin/manifests/deployment.yaml`, run `make validate`,
commit, push, and let Argo sync. Pin a released tag; do not use `latest`.

Argo status:

```bash
kubectl -n argocd get application jellyfin
```

## Backup

Jellyfin's config PVC is **not currently included in Kopia backups**. The media
itself lives on the NAS and is separate. Losing the config LUN would lose
users, libraries, playback settings and watch history.

For a consistent cold backup, stop Jellyfin, run a one-shot pod that mounts the
config PVC, write the archive to the NAS backup share, then start Jellyfin:

```bash
kubectl -n jellyfin scale deploy/jellyfin --replicas=0

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: jellyfin-backup
  namespace: jellyfin
spec:
  restartPolicy: Never
  containers:
    - name: backup
      image: alpine:3.20
      command:
        - sh
        - -c
        - tar -C /config -czf /backup/jellyfin-config-$(date +%F).tgz .
      volumeMounts:
        - name: config
          mountPath: /config
          readOnly: true
        - name: backup
          mountPath: /backup
  volumes:
    - name: config
      persistentVolumeClaim:
        claimName: jellyfin-config
    - name: backup
      nfs:
        server: 192.168.68.138
        path: /volume1/k8s-backups
YAML

kubectl -n jellyfin wait --for=condition=Ready pod/jellyfin-backup
kubectl -n jellyfin logs jellyfin-backup
kubectl -n jellyfin delete pod jellyfin-backup
kubectl -n jellyfin scale deploy/jellyfin --replicas=1
```

Adding the config PVC to the central Kopia policy is the proper follow-up.

## Troubleshooting

| Symptom | Check |
|---|---|
| Pod `Pending` | `kubectl -n jellyfin describe pod`; node `boulder` must be Ready and have capacity. |
| Pod `ContainerCreating` | NFS mount or `/dev/dri` hostPath. Check the pod events and that `192.168.68.138:/volume1/media` is exported read-only to the node. |
| `502`/`504` from the public URL | Traefik pod, Service endpoints, Synology reverse proxy. `kubectl -n jellyfin get endpoints jellyfin`. |
| Library is empty | Media folders are empty or permissions prevent traversal; confirm files exist under `/volume1/media` and the export is readable. |
| Playback stutters, CPU pegged | Hardware transcoding is off or the codec is unsupported; recheck Dashboard -> Playback and the FFmpeg log line. |
| Playback fails only remotely | Check the published server URL and the Synology proxy WebSocket/timeout settings. |

## Notes

- No database migration: Jellyfin keeps its own SQLite data on the config PVC.
- No Authelia: TV and mobile clients cannot complete a browser SSO flow.
- Kyverno reports `disallow-privileged`/`no-hostpath-volumes` warnings for
  `/dev/dri`; those policies are audit-only and the pod is admitted.
- The config PVC and cache are the only cluster-local state. Media stays on the
  NAS.
