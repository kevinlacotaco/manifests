# Homelab TODO

Priorities are impact-first. Check items off when verified, not just deployed.

## P0 — Security and recoverability

- [x] Protect Mealie with Authelia two-factor.
- [x] Protect Donetick with Authelia two-factor (external 302 verified).
- [ ] Confirm Donetick TOTP login and remove any direct Synology bypass.
- [ ] Add the Synology reverse proxy rule for `paperless.lakotko.synology.me` to Traefik and verify the external OIDC login end to end.
- [ ] Remove Traefik `--api.insecure=true`; use `kubectl port-forward` or an Authelia-protected TLS route.
- [ ] Ensure Argo CD is ClusterIP-only and port 8081 is not directly reachable.
- [x] Verify Postgres `fsGroup` on the CSI volume.
- [x] Fix AdGuard `/opt/adguardhome/work` permissions (0775 -> 0700 or document exception).
- [ ] Store Kopia repo password and Renovate GitHub App private key offline; remove plaintext working copies.
- [ ] Run restore tests for Postgres, Authelia, SQLite backups, and Kopia; add offsite replication.

## P1 — Identity and network gaps

- [ ] Decide whether Uptime Kuma should be behind Authelia or kept internal.
- [x] Enable the Authelia OIDC provider and use it for Paperless-ngx.
- [ ] Decide on Authelia OIDC/SSO for Mealie/Argo CD.
- [ ] Tighten egress for `monitoring` and `argocd`; review `ntfy` egress and Traefik `trustedIPs` pod CIDR.
- [ ] Add a second AdGuard instance or MetalLB VIP before router DHCP cutover.
- [ ] Add DNS-specific and TLS-cert-expiry monitoring if not already covered.

## P2 — Reliability and observability

- [ ] Move Grafana SQLite to Postgres or a more reliable volume.
- [ ] Add AdGuard and Authelia metrics/dashboards.
- [ ] Add backup-staleness and certificate-expiry alerts.
- [ ] Investigate node-exporter historical restarts.
- [ ] Add probes to `nfs-subdir-provisioner` and `synology-csi` or document the exception.

## P3 — Automation and documentation

- [ ] Test the committed Ansible baseline in a VM, then apply to boulder/grapple.
- [ ] Ansible phase 2: storage validation and k3s join; phase 3: Zigbee/RTL-SDR/Bluetooth workloads.
- [ ] Renovate: enable GitHub Issues or remove `:dependencyDashboard`; decide weekly vs daily; uninstall old GitHub App; tune custom managers.
- [ ] Update the README known-gaps/checklist and remove completed items.

## Recently completed

- Authelia OIDC provider live; Paperless-ngx deployed with Postgres, Valkey, and NFS storage.
- Authelia protects Mealie and Donetick with two-factor.
- Authelia SQLite/users DB, Uptime Kuma, Speedtest, Grafana SQLite, Postgres dumps, and Mealie media are in Kopia.
- Uptime Kuma monitors Authelia, Kopia backups, and AdGuard DNS.
- Default-deny egress for mealie, donetick, ntfy, speedtest-tracker, auth, and adguard-home.
- Sealed Secrets keyring encrypted offline; no plaintext secrets in the repo.
- Self-hosted Renovate with GitHub App token generator.
- Ansible Phase 1 baseline committed.
