# Homelab Ansible baseline

Phase 1 scaffold. This directory is intentionally untracked for initial review.

## Nodes

| Node | Address | Role | Automation |
| --- | --- | --- | --- |
| boulder | 192.168.68.71 | k3s server (x86) | production; read-only checks only |
| grapple | 192.168.68.53 | k3s worker (Raspberry Pi/ARM64, HA radios) | rebuild target; use `grapple.yml` during maintenance |
| hauler | 192.168.68.102 | k3s worker (reflashable) | first full baseline target |
| adguard-primary (pebble) | 192.168.68.72 | physical DNS (Raspberry Pi 3B, AdGuard Home) | low-traffic; first Pi target |

NAS: 192.168.68.138. Exports: `/volume1/k8s-nfs`, `/volume1/k8s-backups`.
Internal DNS: `home.arpa`, AdGuard at 192.168.68.72 (physical primary) and
192.168.68.71 (cluster secondary). MQTT: existing RabbitMQ.

## Usage

```sh
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-inventory --graph
ansible k3s -m ping
ansible-playbook playbooks/site.yml --check --diff
ansible-playbook playbooks/grapple.yml --check --diff
ansible-playbook playbooks/adguard.yml --check --diff
ansible-playbook playbooks/adguard.yml --diff --ask-become-pass
ansible-playbook playbooks/node-exporter.yml --check --diff
```

`site.yml` is intentionally limited to hauler. Use `grapple.yml` only for the
explicit grapple rebuild. Do not run `site.yml` against `boulder`.
Do not commit `ansible/` until the repo validation is updated to ignore it or a
separate `ansible-lint` target is added. `ansible/` is outside `applications/`,
so Argo CD will not deploy it.

`adguard-primary` is deliberately in its own `adguard` group, so `site.yml`
never touches the physical DNS host. The `adguard_home` role backs up the
existing config, idempotently ensures the shared `home.arpa` DNS rewrites, and
restarts AdGuard only when the config changes. SSH access to the Pi must be set
up first (add the workstation key to the chosen user's `authorized_keys`); sudo
still needs `--ask-become-pass` unless passwordless sudo is configured.

## Grapple radio host

`playbooks/grapple.yml` applies the baseline plus the Pi-specific roles:
`common`, `networking`, `wifi`, `k3s_prerequisites`, `storage`, `hardware`,
and `radios`.

The `radios` role prepares the host, not the Kubernetes apps: it creates
`/dev/zigbee`, installs the rtl-sdr and Zigbee udev rules, blacklists the
RTL-SDR DVB driver, enables BlueZ, and adds `kevin` to `dialout`, `plugdev`, and
`bluetooth`. The Zigbee2MQTT, rtl_433, and Theengs Deployments are separate.

`k3s-join.yml` applies the `homelab.io/radios=true:NoSchedule` taint from
`k3s_node_taints` in `host_vars/grapple.yml` together with the
`homelab.io/radios=true` node label. The radio Deployments select and tolerate
that label/taint, so they stay on grapple. If grapple was joined before this
taint existed, apply it manually:

```sh
kubectl taint node grapple homelab.io/radios=true:NoSchedule
```

The Argo application `radio` owns the Zigbee2MQTT, rtl_433, and Theengs
workloads, plus their MQTT secret, NetworkPolicies, and the Zigbee2MQTT
Service/Ingress. MQTT points at `rabbitmq.messaging.svc.cluster.local:1883`.

The `wifi` role installs `grapple_wpa_supplicant.conf` from the repo root. That
file contains the WiFi PSK and is gitignored; for a fresh image, copy it to the
boot partition as `wpa_supplicant.conf` before first boot so the Pi can join.

## Rollout safety

- **hauler** — reflashable; use it for the first full baseline. `site.yml` is
  intentionally limited to this host.
- **adguard-primary (pebble)** — low traffic; use it for the Pi roles
  (`adguard.yml`, `node-exporter.yml`).
- **boulder** — production; do not run `site.yml` against it. Read-only checks
  only until we add an audit playbook.
- **grapple** — rebuild target; run `grapple.yml` only after the fresh 64-bit
  OS is installed and SSH works. It is not part of `site.yml`.
- Do not run `k3s-join.yml` against boulder. Use `--limit hauler` or
  `--limit grapple`; the playbook delegates the server-token read to boulder,
  so boulder does not need to be in the limit. The playbook sets
  `--flannel-iface` and node labels.
- `k3s-join.yml` downloads the official installer once to
  `/usr/local/share/k3s-install.sh`, then executes it with the pinned
  `k3s_version`, `K3S_URL`, `K3S_TOKEN`, and `INSTALL_K3S_EXEC`. The installer
  creates `/usr/local/bin/k3s` and the `k3s-agent.service` unit; the playbook
  then enables and starts the service.
- `host_vars/hauler.yml` sets `homelab_resolv_conf_direct: true` because
  hauler's systemd-resolved stub refuses normal resolver clients on
  `127.0.0.53`. That makes hauler use AdGuard directly in `/etc/resolv.conf`;
  otherwise kubelet and containerd fail image pulls with DNS `Try again`.

## Phase plan

1. Baseline: `common`, `networking`, `k3s_prerequisites`, `storage`, `hardware`.
2. Security/time, storage validation, k3s join.
3. Zigbee, RTL-SDR, and Bluetooth workloads in Argo with USB passthrough.

