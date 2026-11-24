# US-only geoblocking

Status: **enabled** (2026-11-18). Public HTTP(S) ingress through Traefik is
restricted to clients geolocated in the United States. Private/LAN clients and
an explicit health/ACME allowlist bypass the check.

## How it works

Traefik runs the [GeoBlock](https://github.com/PascalMinder/geoblock) plugin
`v0.3.8` on the `web` and `websecure` entrypoints, after the global CrowdSec
bouncer:

```text
crowdsec-bouncer,geoblock
```

The middleware is `kube-system/geoblock`:

- `countries: [US]` — allowlist mode.
- `allowLocalRequests: true` — RFC1918/loopback clients are always allowed.
- `xForwardedForReverseProxy: true` — use the first `X-Forwarded-For` entry.
  Synology sets the real client address and Traefik trusts
  `192.168.68.138`, so lookups use the public client IP rather than the proxy.
- `cacheSize: 10000`, `cacheTtlSeconds: 86400` — one lookup per client IP per
  day; cached results keep normal traffic off the lookup API.
- `allowUnknownCountries: false` — an IP with no country is denied.
- `ignoreApiTimeout: true`, `ignoreApiFailures: false` — a timeout is allowed
  so a stalled lookup API cannot take the ingress offline. Other lookup
  failures, including an empty response with no country, are denied. CrowdSec
  still applies its own decisions.
- Denied requests receive `403`.
- `X-IPCountry` is added to allowed requests for troubleshooting.

The lookup API is `https://get.geojs.io/v1/ip/country/{ip}`. Traefik needs
egress to it, plus GitHub for plugin downloads.

## What is covered

Covered:

- Every Ingress served through the Traefik `web`/`websecure` entrypoints,
  including Authelia-protected and public apps under
  `*.lakotko.synology.me`.
- Jellyfin, Homepage, Forgejo, Paperless, Mealie, Donetick, Omni Tools, ntfy,
  Uptime Kuma, Speedtest, Frigate, Home Assistant, Zigbee2MQTT, and so on.

Not covered:

- MQTT `1883` (it is a TCP entrypoint, not HTTP).
- Synology DSM itself.
- Traffic that reaches a pod without passing through Traefik.

Grafana and the Traefik dashboard now use `websecure` hostnames, so there are
no direct HTTP admin ports to exempt. If a direct admin port is ever added,
geoblocking will not protect it; remove the port forward or put it behind
Traefik instead.

## Verify

A US client should still get the normal response:

```bash
curl -I https://home.lakotko.synology.me/
```

A non-US client should get `403`. If you have a trusted proxy/VPN outside the
US, confirm it is denied before relying on the rule.

Check Traefik loaded the middleware without plugin errors:

```bash
kubectl -n kube-system get middleware geoblock -o yaml
kubectl -n kube-system logs deploy/traefik --tail=100 | grep -i geoblock
```

The Traefik dashboard/API should list `kube-system-geoblock@kubernetescrd`.

## Change the allowlist

Edit `countries` in
`applications/platform/traefik/geoblock-middleware.yaml`, then validate,
commit, push, and refresh Argo. Add ISO-3166 alpha-2 codes, for example:

```yaml
countries:
  - US
  - CA
```

Do not remove `allowLocalRequests` unless you also add the LAN ranges to
`allowedIPAddresses`; otherwise internal clients will be sent to the
geolocation API and may be denied.

## Disable

Remove `kube-system-geoblock@kubernetescrd` from the two
`--entryPoints.*.http.middlewares` arguments in
`applications/platform/traefik/entry-points.yaml`, then sync. The middleware
object can stay; it is inert until referenced.

## Caveats

- Geolocation is approximate. VPNs, corporate egress, CGNAT, and stale GeoIP
  data can misclassify a client. US travelers using a non-US VPN will be
  blocked.
- IPv6 addresses are looked up too; if a client has no country mapping it is
  denied because `allowUnknownCountries` is `false`.
- The rule is country-level, not a substitute for authentication. Authelia and
  CrowdSec remain in place.
- The plugin is third-party code executed by Traefik. Pin the version and
  review changes before upgrading.
