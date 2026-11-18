# Home Assistant configuration in Git

Status: active. `configuration.yaml` and template entities are maintained in
this repository (`applications/apps/home-assistant/manifests/config/`) and
copied onto the Home Assistant config volume when the pod starts.

## What is managed in Git

| Path | Purpose |
|---|---|
| `manifests/config/configuration.yaml.tpl` | Main `configuration.yaml` |
| `manifests/config/templates/*.yaml.tpl` | Template entities, merged with `!include_dir_merge_list templates` |

The `.tpl` extension is deliberate: repository validation treats every
`applications/**/*.yaml` file as a Kubernetes manifest, and Home Assistant
files use `!include` tags that are not valid Kubernetes YAML. The kustomize
generator publishes them to the ConfigMap with normal `.yaml` keys.

## How it reaches the pod

1. `kustomization.yaml` builds ConfigMap `home-assistant-git-config` from the
   files under `config/`.
2. The `sync-config` init container runs after `restore-config` and before
   Home Assistant starts.
3. It copies `configuration.yaml` to `/config/configuration.yaml` and every
   `template-*.yaml` key to `/config/templates/`.

Git is the source of truth for these files. If you edit them from the Home
Assistant UI or the File Editor, the change is overwritten the next time the
pod starts. Edit the repository instead.

## Adding a template

1. Create `applications/apps/home-assistant/manifests/config/templates/my_template.yaml.tpl`.
   The file must contain a list fragment, for example:

   ```yaml
   - binary_sensor:
       - name: "My Template"
         state: >
           {{ is_state('binary_sensor.example', 'on') }}
   ```

2. Add it to the generator in `manifests/kustomization.yaml`:

   ```yaml
   - template-my_template.yaml=config/templates/my_template.yaml.tpl
   ```

3. Run `make validate`, commit, push, and let Argo sync. Restart the
   deployment if Argo does not roll it automatically:

   ```bash
   kubectl -n home-assistant rollout restart deploy/home-assistant
   ```

No deployment change is needed; the init container copies every
`template-*.yaml` key.

## Guarding templates against missing states

Template sensors often read entities that can be `unknown` or `unavailable`
during startup or when an integration is down. Convert values only after
checking the raw state:

```jinja
{% set raw = states('sensor.example') %}
{% if raw not in ['unknown', 'unavailable', 'none'] %}
  {{ (raw | float(0)) == 0 }}
{% endif %}
```

Returning nothing makes the template entity unknown instead of raising
`ValueError: float got invalid input 'unavailable'`. Prefer this over
`| float` when the source can legitimately be missing.

## What is not in Git

These stay on the `home-assistant-config` PVC because Home Assistant writes
them at runtime:

- `.storage/` (registries, auth, integration config entries)
- `home-assistant_v2.db` (history database)
- `custom_components/` and `blueprints/`
- `automations.yaml`, `scripts.yaml`, `scenes.yaml` (currently UI-editable)
- `secrets.yaml`
- `govee_learning.yaml`
- `www/`, `tts/`, `ssl/`, `backups/`, `component-backups/`

Do not move the database or `.storage` into Git. Automations and scripts can
be migrated later if you want them declarative, but that makes UI edits
temporary in the same way as `configuration.yaml`.

## Validation and rollback

- `make validate` checks the rendered ConfigMap and the deployment.
- A bad configuration makes Home Assistant fail at startup. Check logs with:

  ```bash
  kubectl -n home-assistant logs deploy/home-assistant --tail=100
  ```

- To roll back, revert the config change in Git and let Argo sync, or restore
  the previous PVC snapshot/backup.
- Cold backups live under `/volume1/k8s-backups/upgrades/` on the NAS.

## Manual check after a rollout

```bash
kubectl -n home-assistant logs deploy/home-assistant -c sync-config
kubectl -n home-assistant exec deploy/home-assistant -c home-assistant -- \
  sh -c 'tail -5 /config/configuration.yaml; ls -l /config/templates'
kubectl -n home-assistant logs deploy/home-assistant --since=10m | \
  grep -Ei 'TemplateError|float got invalid'
```

The last command should return nothing.
