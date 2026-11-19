# Add `hauler` as a K3s worker

**Status:** untracked scratch runbook. Review before committing.

## Current state

- `boulder` `192.168.68.71` is the only K3s server, version `v1.31.4+k3s1`.
- `hauler` `192.168.68.102` is listed under `k3s_workers` in
  `ansible/inventory/homelab/hosts.yml` (commit `13dd07b`).
- `ansible/inventory/homelab/group_vars/k3s.yml` pins:
  - `k3s_version: "v1.31.4+k3s1"`
  - `k3s_server_url: "https://192.168.68.71:6443"` (commit `14da90c`).
- The node token is **not** stored in Git. The playbook reads
  `/var/lib/rancher/k3s/server/node-token` from `boulder` as root and passes it
  to the worker join.

`hauler` is a worker, not a control-plane server. This adds capacity, not
control-plane HA. If HA is wanted later, plan three reliable K3s server nodes.

## Prerequisites

1. SSH and sudo/root access to `boulder` and `hauler`.
2. A static address/reservation for `hauler` (`192.168.68.102`).
3. Hostname set to `hauler`.
4. Time sync enabled.
5. Required packages/ports:
   - `curl`, `ca-certificates`, `iptables`/`nftables`.
   - `hauler` -> `boulder`: TCP `6443`.
   - Worker overlay: UDP `8472`.
   - Kubelet/metrics: TCP `10250` (and any metrics ports in use).
6. Confirm the server certificate includes the address used by
   `k3s_server_url`. If joining by IP fails with an x509 error, check the
   server's `--tls-san`; do not disable TLS verification.
7. Set `ansible_user` in inventory or pass `-u <ssh-user>`. The inventory does
   not currently define a user.

## Run

From the repository root:

```sh
ansible-playbook \
  -i ansible/inventory/homelab/hosts.yml \
  ansible/playbooks/k3s-join.yml \
  --limit 'boulder:hauler' \
  -u <ssh-user> \
  --ask-become-pass
```

`--limit 'boulder:hauler'` is intentional: the first play needs `boulder` to
read the token, and the second play joins only `hauler`. Without `boulder` in
the limit, the token fetch would be skipped.

If `boulder` and `hauler` use different SSH users, set per-host
`ansible_user` in the inventory instead of `-u`.

## What the playbook does

1. Reads `/var/lib/rancher/k3s/server/node-token` from `boulder` with
   `ansible.builtin.slurp` as root.
2. Decodes the token in memory; it is not written to the repo.
3. On each selected worker, installs the K3s agent with:
   - `INSTALL_K3S_VERSION` from `k3s_version`
   - `K3S_URL` from `k3s_server_url`
   - `K3S_TOKEN` from the fetched token
   - `--node-name hauler --node-ip 192.168.68.102`
4. Ensures `k3s-agent` is enabled and running.

The playbook skips the install if `/usr/local/bin/k3s` already exists.

## Verify

```sh
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide | grep -E 'hauler|kube-proxy|flannel'
ssh <ssh-user>@192.168.68.102 sudo systemctl status k3s-agent
```

Expected: `hauler` is `Ready`, and `k3s-agent` is active.

Optional labels/taints:

```sh
kubectl label node hauler node-role.kubernetes.io/worker= --overwrite
# If this is the hardware/radio node:
kubectl taint node hauler hardware=true:NoSchedule
```

Only add the taint if workloads should be prevented from scheduling there by
default; use matching tolerations for the hardware workloads.

## Troubleshooting

- Agent logs: `ssh <ssh-user>@192.168.68.102 sudo journalctl -u k3s-agent -f`
- Server reachability: `curl -k https://192.168.68.71:6443/version`
- Token file: `ssh <ssh-user>@192.168.68.71 sudo cat /var/lib/rancher/k3s/server/node-token`
  Do not paste the token into Git or chat.
- Version mismatch: both sides must use `v1.31.4+k3s1`.
- Time skew, firewall, or wrong `ansible_host` can prevent registration.
- If the playbook reports a TLS/x509 error, check the server `--tls-san` and
  use the matching hostname/IP in `k3s_server_url`.

## Rollback

On `hauler`:

```sh
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

Then remove the node object from the cluster if it remains:

```sh
kubectl delete node hauler
```

## Security notes

- The node token is a cluster join secret. Keep it out of Git; rotate it if it
  leaks.
- Any worker can access cluster state/secrets through the kubelet and pod
  scheduling. Treat `hauler` as a trusted cluster node.
- A worker does not provide control-plane HA.
