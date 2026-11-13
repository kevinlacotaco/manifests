# Architecture

This file holds the current and proposed homelab architecture diagrams. Update
the Mermaid blocks here when the network, cluster, ingress, storage, or hardware
node changes.

Solid lines are traffic paths. Dashed lines are DNS, storage, radio, or
observability relationships.

## Current architecture

Everything runs on one k3s node (`boulder`), which is currently reached over
2.4 GHz Wi-Fi. Synology is the public TLS/reverse-proxy edge and the
storage/backup target.

```mermaid
flowchart TB
  subgraph WAN["Internet / WAN"]
    REMOTE["Remote users"]
    PUBDNS["Public DNS<br/>*.lakotko.synology.me"]
    ISP["ISP"]
    MODEM["Cable modem"]
  end

  subgraph HOME["Home LAN - 192.168.68.0/24"]
    ROUTER["Deco XE75<br/>router / NAT / Wi-Fi"]
    CLIENTS["LAN and Wi-Fi clients"]
    SYNOLOGY["Synology DS220+<br/>192.168.68.138<br/>wildcard TLS + reverse proxy<br/>NFS / iSCSI / Kopia target"]
    BOULDER["boulder<br/>192.168.68.71<br/>single k3s node"]
  end

  subgraph K3S["k3s workloads on boulder"]
    TRAEFIK["Traefik<br/>LoadBalancer 80/443"]
    ING["Ingress / IngressRoute"]
    SVC["Kubernetes Services"]
    AUTHELIA["Authelia<br/>forward-auth + OIDC"]
    APPS["Application pods<br/>Mealie, Paperless, Donetick,<br/>Omni Tools, ntfy, Speedtest"]
    DATA["Postgres + Valkey<br/>single instance"]
    OBS["Prometheus, Grafana, Loki,<br/>Uptime Kuma, Alloy"]
    BACKUP["Kopia + database dump jobs"]
    ADGUARD["AdGuard Home<br/>DNS / blocklists"]
  end

  REMOTE -.->|"DNS lookup"| PUBDNS
  PUBDNS -.->|"public IP"| REMOTE
  REMOTE -->|"443"| ISP --> MODEM --> ROUTER

  ROUTER -->|"current: 2.4 GHz Wi-Fi"| BOULDER
  ROUTER -->|"wired"| SYNOLOGY
  ROUTER --> CLIENTS
  CLIENTS -.->|"not primary DNS yet"| ADGUARD
  CLIENTS -->|"https://app.lakotko.synology.me"| SYNOLOGY

  ROUTER -->|"443 port forward"| SYNOLOGY
  SYNOLOGY -->|"Host-based reverse proxy"| TRAEFIK
  TRAEFIK --> ING --> SVC --> APPS
  TRAEFIK --> AUTHELIA
  AUTHELIA -.->|"forward-auth / OIDC"| APPS

  BOULDER -->|"runs"| K3S
  APPS --> DATA
  APPS --> OBS
  BACKUP --> SYNOLOGY
  SYNOLOGY -.->|"NFS RWX"| APPS
  SYNOLOGY -.->|"iSCSI RWO"| DATA
  SYNOLOGY -.->|"Kopia repository"| BACKUP
  OBS -.->|"node-exporter / SNMP"| BOULDER
  OBS -.->|"SNMP"| SYNOLOGY
```

## Proposed multi-node architecture

The main changes are:

- Wire the modem, router, switch, nodes, and Synology together.
- Run k3s across three wired nodes: `boulder`, `grapple`, and a dedicated
  hardware node.
- Use MetalLB VIPs for ingress and AdGuard DNS instead of pointing at one node
  IP.
- Keep Synology as the near-term edge proxy, TLS terminator, storage provider,
  and backup target.
- Taint the hardware node and pin USB-radio workloads to it.

```mermaid
flowchart TB
  subgraph WAN["Internet / WAN"]
    REMOTE["Remote users"]
    PUBDNS["Public DNS<br/>*.lakotko.synology.me"]
    ISP["ISP"]
    MODEM["Cable modem"]
  end

  subgraph EDGE["Edge / LAN"]
    ROUTER["Router / firewall<br/>Deco XE75 now<br/>dedicated firewall optional"]
    SWITCH["Managed switch<br/>1 / 2.5 GbE<br/>wired shelf"]
    AP["Wi-Fi AP / Deco mesh"]
    CLIENTS["LAN clients"]
    IOT["IoT radios and devices<br/>Zigbee sensors, 433 MHz, BLE"]
  end

  subgraph CLUSTER["k3s cluster - 3 wired nodes"]
    BOULDER["boulder<br/>k3s server + worker<br/>general apps"]
    GRAPPLE["grapple<br/>k3s server + worker<br/>general apps"]
    HARDWARE["hardware node<br/>k3s server + worker<br/>taint: hardware=true:NoSchedule<br/>USB radios"]

    subgraph PLATFORM["platform pods"]
      ADGUARD["AdGuard Home x2<br/>MetalLB DNS VIP"]
      VIP["MetalLB VIP<br/>Traefik 80/443"]
      TRAEFIK["Traefik"]
      ING["Ingress / IngressRoute"]
      SVC["Kubernetes Services"]
      AUTHELIA["Authelia<br/>forward-auth + OIDC"]
      WEBAPPS["Application pods<br/>Mealie, Paperless, Donetick,<br/>Omni Tools, ntfy, Speedtest"]
      DATA["Postgres + Valkey<br/>single writer"]
      PROM["Prometheus + Grafana + Loki"]
      KUMA["Uptime Kuma"]
      KOPIA["Kopia + database dumps"]
    end

    subgraph HWWORK["hardware workflows - pinned to hardware node"]
      ZIGBEE["zigbee2mqtt<br/>USB Zigbee coordinator"]
      MQTT["Mosquitto MQTT"]
      RTL["rtl_433<br/>USB RTL-SDR"]
      BLE["BLE collector<br/>hostNetwork + D-Bus"]
      AUTOMATION["Home Assistant / automation"]
    end
  end

  subgraph STORAGE["Synology NAS - 192.168.68.138"]
    EDGEPROXY["Reverse proxy + wildcard TLS<br/>near-term edge"]
    NFS["NFS RWX<br/>media / shared data"]
    ISCSI["iSCSI RWO<br/>Postgres / SQLite"]
    KOPIAREPO["Kopia repository"]
  end

  REMOTE -.->|"DNS lookup"| PUBDNS
  PUBDNS -.->|"public IP"| REMOTE
  REMOTE -->|"443"| ISP --> MODEM --> ROUTER

  ROUTER --> SWITCH
  SWITCH --> BOULDER
  SWITCH --> GRAPPLE
  SWITCH --> HARDWARE
  SWITCH --> STORAGE
  ROUTER --> AP
  AP --> CLIENTS

  ROUTER -->|"DHCP DNS"| ADGUARD
  CLIENTS -->|"internal names"| ADGUARD
  ADGUARD -.->|"A / rewrite -> ingress VIP"| VIP

  ROUTER -->|"443 port forward"| EDGEPROXY
  EDGEPROXY -->|"Host -> Traefik"| VIP
  VIP --> TRAEFIK --> ING --> SVC --> WEBAPPS
  TRAEFIK --> AUTHELIA
  AUTHELIA -.->|"forward-auth / OIDC"| WEBAPPS

  WEBAPPS --> DATA
  DATA -.->|"iSCSI RWO"| ISCSI
  WEBAPPS -.->|"NFS RWX"| NFS
  KOPIA -.->|"snapshot target"| KOPIAREPO

  HARDWARE -->|"USB coordinator"| ZIGBEE
  HARDWARE -->|"USB SDR"| RTL
  HARDWARE -->|"D-Bus / hostNetwork"| BLE
  IOT -.->|"Zigbee 802.15.4"| ZIGBEE
  IOT -.->|"433 MHz"| RTL
  IOT -.->|"Bluetooth LE"| BLE
  ZIGBEE --> MQTT
  RTL --> MQTT
  BLE --> MQTT
  MQTT --> AUTOMATION
  AUTOMATION -.->|"events / API"| WEBAPPS

  PROM -.->|"node-exporter / kubelet"| BOULDER
  PROM -.->|"node-exporter / kubelet"| GRAPPLE
  PROM -.->|"node-exporter / hardware exporters"| HARDWARE
  PROM -.->|"SNMP"| STORAGE
  KUMA -.->|"probe"| VIP
```

## Request path

Public traffic:

```text
Remote user
  -> public DNS (*.lakotko.synology.me)
  -> ISP / modem / router
  -> Synology wildcard TLS + reverse proxy
  -> MetalLB ingress VIP
  -> Traefik
  -> Ingress / IngressRoute
  -> Kubernetes Service
  -> application pod
```

Internal traffic:

```text
LAN client
  -> AdGuard DNS VIP
  -> MetalLB ingress VIP
  -> Traefik
  -> Ingress / IngressRoute
  -> Kubernetes Service
  -> application pod
```

## Hardware-node responsibility

The hardware node should be the only place these pods run:

| Workflow | Device / dependency | Scheduling |
| --- | --- | --- |
| `zigbee2mqtt` | USB Zigbee coordinator, e.g. `/dev/ttyACM0` | `nodeSelector: hardware=true`, toleration, hostPath/device mount |
| `rtl_433` | USB RTL-SDR, `/dev/bus/usb` | Same node pinning; privileged or USB device access |
| BLE collector | Bluetooth adapter, D-Bus | `hostNetwork: true`, `/var/run/dbus` mount, node pinning |
| Mosquitto / automation | Local MQTT and automation state | Prefer the hardware node for radio locality |
| Home Assistant | MQTT broker, radio integrations | Hardware node, or general node with MQTT reachability |

General applications, Postgres, Valkey, and observability stay on
`boulder`/`grapple`. The hardware node gets a taint such as
`hardware=true:NoSchedule`, and only the radio workloads get the matching
toleration. That prevents a general pod from competing for USB devices or being
disrupted when the radio node reboots.

## Caveats

- This is **multi-node, not fully HA**. Three k3s servers give etcd quorum, but
  Postgres, Valkey, Synology, and the ISP connection remain single points of
  failure.
- True HA later needs Postgres replication or an operator, Redis/Valkey HA, a
  second NAS or offsite copy, and possibly dual WAN.
- Keep Synology as the edge proxy initially because the wildcard certificate and
  reverse-proxy rules already work. Moving edge/TLS fully into Traefik with
  MetalLB and cert-manager is a separate project.
- Use dedicated MetalLB VIPs: one for ingress, one for AdGuard DNS. Do not hand
  out a node IP through DHCP.
- If the hardware node is small, make it a k3s **agent** and add a separate small
  control-plane node; do not force etcd onto a device that may reboot for USB
  maintenance.
