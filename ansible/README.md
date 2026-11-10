# Homelab Ansible baseline

Phase 1 scaffold. This directory is intentionally untracked for initial review.

## Nodes

| Node | Address | Role |
| --- | --- | --- |
| boulder | 192.168.68.71 | k3s server (x86) |
| grapple | 192.168.68.53 | k3s worker (Raspberry Pi/ARM64) |

NAS: 192.168.68.138. Exports: `/volume1/k8s-nfs`, `/volume1/k8s-backups`.
Internal DNS: `home.arpa`, AdGuard at 192.168.68.71. MQTT: existing RabbitMQ.

## Usage

```sh
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-inventory --graph
ansible k3s -m ping
ansible-playbook playbooks/site.yml --check --diff --limit grapple
```

Do not run against `boulder` first. Use `--limit grapple` for the first check.
Do not commit `ansible/` until the repo validation is updated to ignore it or a
separate `ansible-lint` target is added. `ansible/` is outside `applications/`,
so Argo CD will not deploy it.

## Phase plan

1. Baseline: `common`, `networking`, `k3s_prerequisites`, `storage`, `hardware`.
2. Security/time, storage validation, k3s join.
3. Zigbee, RTL-SDR, and Bluetooth workloads in Argo with USB passthrough.

