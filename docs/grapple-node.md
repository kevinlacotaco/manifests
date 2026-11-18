# Grapple radio node

Status: **planned / not yet joined**. `grapple` is a small Raspberry Pi that
exists only to run the radio containers. Nothing else should be scheduled on it.

## Scheduling contract

| Item | Value |
|---|---|
| Node name | `grapple` |
| Address | `192.168.68.53` (WiFi, `wlan0`) |
| Taint | `homelab.io/radios=true:NoSchedule` |
| Labels | `homelab.io/radios=true`, `homelab.io/zigbee=true`, `homelab.io/rtl433=true`, `homelab.io/bluetooth=true` |
| Allowed workloads | `radio/zigbee2mqtt`, `radio/rtl433`, `radio/theengs` |
| Allowed monitoring | `monitoring/prometheus-prometheus-node-exporter` |

Those three Deployments select the node and tolerate the taint:

```yaml
nodeSelector:
  homelab.io/radios: "true"
tolerations:
  - key: homelab.io/radios
    operator: Equal
    value: "true"
    effect: NoSchedule
```

Node-exporter is the only non-radio DaemonSet allowed to tolerate the taint.
Every other workload either has no matching toleration or is a Deployment that
the scheduler would not place on a tainted node. That includes the Alloy
DaemonSet, CrowdSec agent, Synology CSI node plugin, Loki canary and the k3s
service-load-balancer pods.

## Where the node configuration lives

- `ansible/inventory/homelab/host_vars/grapple.yml` defines `k3s_node_taints`
  and `k3s_node_labels`.
- `ansible/playbooks/k3s-join.yml` passes them to the k3s installer as
  `--node-taint` and `--node-label`.
- `ansible/inventory/homelab/group_vars/k3s.yml` provides empty defaults for
  other workers.
- `ansible/playbooks/grapple.yml` applies the baseline roles (`common`,
  `networking`, `wifi`, `k3s_prerequisites`, `storage`, `hardware`, `radios`).

These Ansible files are currently part of the user's in-progress work; review
and commit them separately from application changes.

## Monitoring on grapple

`prometheus-node-exporter` is intentionally allowed:

- `applications/observability/monitoring/prometheus.yaml` keeps the
  `homelab.io/radios=true:NoSchedule` toleration for node-exporter.

`alloy` is deliberately **not** allowed:

- `applications/observability/monitoring/alloy.yaml` has no radios toleration.

The trade-off: the Pi reports basic node metrics (CPU, memory, filesystem) but
its container logs are not shipped by Alloy. Radio application logs remain
available with `kubectl logs`. Add Alloy only if log shipping is worth the
memory/CPU cost on the Pi.

## Verify after the node joins

```bash
kubectl get nodes -o wide
kubectl describe node grapple | sed -n '/Taints/,/Unschedulable/p'
kubectl get pods -A --field-selector spec.nodeName=grapple
```

Expected taint:

```text
homelab.io/radios=true:NoSchedule
```

Expected pods: the three radio pods plus exactly one
`monitoring/prometheus-prometheus-node-exporter-*` pod. No Alloy, CrowdSec,
CSI, Loki canary or service-load-balancer pods.

Confirm DaemonSet counts:

```bash
kubectl -n monitoring get ds
```

Expected: node-exporter has **3** desired pods (boulder, hauler, grapple);
Alloy still has **2**.

## If the node was joined before the taint existed

The join playbook only passes labels/taints on the first install. If `grapple`
is already registered, apply the guard directly:

```bash
kubectl label node grapple homelab.io/radios=true homelab.io/zigbee=true \
  homelab.io/rtl433=true homelab.io/bluetooth=true --overwrite
kubectl taint node grapple homelab.io/radios=true:NoSchedule --overwrite
```

Then evict anything already running there:

```bash
kubectl get pods -A --field-selector spec.nodeName=grapple
```

Delete any non-radio pod and let its controller reschedule elsewhere.

## Allowing a future workload

A workload that genuinely belongs on the Pi needs both:

1. `nodeSelector: { homelab.io/radios: "true" }`
2. the matching toleration shown above.

Do not add the toleration to shared DaemonSets or broad Deployments just to
"make it run"; that reintroduces the problem this node exists to avoid.

## Radio hardware

Device mappings and USB permissions live in `ansible/inventory/homelab/host_vars/grapple.yml`
and the `radios` role. The radio containers use hostPath device mounts only, no
PVCs, so `grapple` does not need the Synology CSI node plugin.

## Known runtime details

- **Zigbee adapter type:** Zigbee2MQTT 2.x does not infer the adapter. The
  ConfigMap sets `serial.adapter: zstack` for the Sonoff CC2652P dongle.
  `prepare-data` only writes `/var/lib/zigbee2mqtt/configuration.yaml` when it
  is missing, so an existing volume keeps its old file. Add the adapter there
  once, or remove the file and let the init container regenerate it.
- **Device access:** mounting `/dev` is not enough. The default device cgroup
  denies `open()` on the Zigbee character device, so the Zigbee container runs
  privileged. The other radio containers already do.
- **DNS:** `/etc/resolv.conf` is symlinked to the systemd-resolved stub, and
  NetworkManager is set to `rc-manager=unmanaged` so it is not overwritten.
  This is required for containerd image pulls after a reboot.
- **First join:** image pulls can fail while DNS settles. If a pod sits in
  `ContainerCreating` with `lookup registry-1.docker.io: Try again`, verify
  `getent ahostsv4 registry-1.docker.io`, then delete the pod to retry.
- **Memory:** the Pi has about 905 MiB RAM. With all three radios and
  node-exporter running, usage is roughly 420 MiB. The configured limits total
  960 MiB, so watch for OOM if more workloads are ever allowed.
