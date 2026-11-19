# govee2mqtt

Govee bridge running in the cluster. It replaces the old Docker container on the
Synology NAS and publishes Govee plugs, lights, and H5106 air-quality monitors to
RabbitMQ for Home Assistant discovery.

## Where it runs

| Item | Value |
|---|---|
| Argo app | `govee2mqtt` |
| Namespace | `govee2mqtt` |
| Manifest path | `applications/apps/govee2mqtt/manifests` |
| Image | `ghcr.io/wez/govee2mqtt` pinned by digest |
| Node | `hauler` |
| Networking | `hostNetwork: true`, `dnsPolicy: ClusterFirstWithHostNet` |
| HTTP API | `http://192.168.68.102:8056` |

Host networking is required for Govee LAN discovery (multicast) and mirrors the
old NAS container. Kyverno reports the host-namespace policy as an audit warning;
the namespace enforces `privileged` Pod Security.

The container is stateless from Kubernetes' perspective. The AWS IoT key and
certificate are generated on first login and stored in an `emptyDir`; no PVC is
needed. A restart re-authenticates with the Govee cloud.

## MQTT

| Item | Value |
|---|---|
| Broker | `rabbitmq.messaging.svc.cluster.local:1883` |
| User | `govee2mqtt` |
| App secret | `govee2mqtt-secrets` in `govee2mqtt` |
| RabbitMQ auth secret | `govee2mqtt-mqtt-auth` in `messaging` |
| User-sync Job | `rabbitmq-govee2mqtt-mqtt-user` |

The app secret contains `GOVEE_API_KEY`, `GOVEE_EMAIL`, `GOVEE_PASSWORD`, and
`GOVEE_MQTT_PASSWORD`. Both secrets are SealedSecrets; no plaintext is committed.

Discovery is published under `homeassistant/<domain>/<unique_id>/config`.
State and command topics use the `gv2mqtt/` prefix.

govee2mqtt listens for `homeassistant/status online` and re-registers entities
about 15 seconds after Home Assistant starts, so a HA restart does not require a
bridge restart.

## Home Assistant devices

- Four H5083 smart plugs: Willy, Kitchen, LR Smart Plug 2, Bathroom.
- Four H5106 air-quality monitors: Bonus Room, Basement, Master Bedroom, Attic.
- H6093 Star Light Projector.

The H5106 devices are assigned to the matching HA areas and their temperature and
humidity entities carry the `climate` label.

## Operations

Logs:

```bash
kubectl -n govee2mqtt logs deploy/govee2mqtt --tail=100 -f
```

Restart:

```bash
kubectl -n govee2mqtt rollout restart deploy/govee2mqtt
kubectl -n govee2mqtt rollout status deploy/govee2mqtt
```

Check the bridge is connected to both Govee IoT and RabbitMQ:

```bash
kubectl -n govee2mqtt logs deploy/govee2mqtt --tail=200 \
  | grep -E 'Connected to IoT|Connected to mqtt broker|http server'
```

Check the MQTT user:

```bash
kubectl -n messaging exec rabbitmq-server-0 -- rabbitmqctl list_users | grep govee2mqtt
```

## Rotating the MQTT password

1. Generate a new password.
2. Reseal `govee2mqtt-mqtt-auth` (`username`, `password`) in `messaging`.
3. Reseal `govee2mqtt-secrets` (`GOVEE_MQTT_PASSWORD`) in `govee2mqtt` with the
   same value.
4. Commit, push, and sync the `rabbitmq` and `govee2mqtt` apps.
5. The PostSync Job updates the RabbitMQ user, then restart the Deployment so the
   new environment is loaded:
   `kubectl -n govee2mqtt rollout restart deploy/govee2mqtt`.

## Updating the image

Use a registry manifest digest, not the local Docker image ID:

```bash
docker buildx imagetools inspect ghcr.io/wez/govee2mqtt:latest
```

Update the `image:` digest in `deployment.yaml`, validate, commit, and sync.

## NAS rollback

The old NAS container is stopped but retained. To roll back temporarily:

```bash
# DSM Container Manager, or the DSM Docker API
SYNO.Docker.Container method=start name=govee2mqtt
```

It still points at the old `192.168.128.2` broker and the missing `govee2mqtt`
RabbitMQ user, so it will not publish until reconfigured. Stop it again before
using the cluster bridge.

## Known warning

`community-api.govee.com` fails to resolve from the pod. This only affects
Govee community "one-click" scenes; device state, discovery, and control work.
