# Home Assistant entity IDs and dashboards

Status: proposal (2026-11-18). Nothing in this document changes the running
cluster or Home Assistant by itself.

Current inventory: **1276 entities** across 155 devices and 15 areas. 822 are
enabled and 454 are disabled. **684 entities are unavailable**, the Overview
dashboard is the auto-generated `original-states` page, and no entity has a
label.

## What is causing the clutter

| Issue | Evidence |
|---|---|
| One auto-generated dashboard | `lovelace.lovelace` only has `{"strategy":{"type":"original-states"}}` |
| Stale Docker entities | 112 `switch.ironhide_docker_*` entities remain after `monitor_docker` was removed |
| Unavailable discovery entities | 684 of 821 checked entities report unavailable |
| Missing area assignment | 693 entities have no area; 460 of them are MQTT |
| Duplicated names | `sensor.garage_garage_fridge_sensor_garage_fridge_temperature` |
| Vendor/model/hash in IDs | `sensor.smart_air_quality_monitor_304b95_h5106_pm25` |
| Raw Zigbee addresses | `sensor.0x282c02bfffec3463_power`, `light.0x001788010f...` |
| Wrong locations | `media_player.office_tv_2` and `office_tv_3` are in the Living Room |
| No labels | 0 entities use labels, so cross-cutting views cannot be built |

The Docker entities and a large share of the unavailable entities are leftovers
from integrations or discovery records that no longer exist. Cleaning those is
the single largest improvement and does not require renaming anything.

## Entity ID convention

Use:

```text
<area>_<device>_<function>
```

Examples:

```text
sensor.garage_freezer_temperature
sensor.garage_fridge_humidity
binary_sensor.garage_freezer_door
switch.kitchen_coffee_maker
sensor.master_bedroom_temperature
sensor.master_bedroom_climate_battery
sensor.living_room_ac_filter_life
binary_sensor.second_floor_bathroom_leak
sensor.home_grid_power
sensor.home_solar_power
```

Rules:

1. **Keep the domain** (`sensor`, `binary_sensor`, `switch`, `light`, ...).
2. **Start with the area** for physical devices. Use `home_` for whole-house
   systems such as grid, solar, and internet.
3. **Use the device name**, not its brand, model, IP, MAC, or Zigbee address.
4. **End with the function or measurement** (`temperature`, `humidity`,
   `battery`, `power`, `energy`, `fps`, `leak`, `filter_life`).
5. **Do not repeat words.** `garage_fridge_temperature`, not
   `garage_garage_fridge_sensor_garage_fridge_temperature`.
6. **Do not encode state or units** in the ID. `battery`, not
   `battery_state`; `temperature`, not `temperature_c`.
7. Keep the entity's `unique_id` unchanged. Renaming the entity ID in the UI
   preserves history and registry identity.
8. Prefer assigning the **device** to an area; only override the entity area
   when a device genuinely spans rooms.
9. Keep user-facing names short. With device `Garage Freezer` and entity name
   `Temperature`, Home Assistant renders `Garage Freezer Temperature`
   automatically.

### Areas

The existing 15 areas are a good base. Add the missing physical spaces:

- First Floor Bathroom
- Second Floor Bathroom
- Hallway
- Porch or Front Yard (or fold into Outside)
- Utility or Network (for hubs, NAS, and network gear)

Do not assign areas to `mobile_app`, `person`, or phone trackers. Those are
people, not rooms.

### Labels

Use labels for cross-cutting dashboards and automations:

```text
energy        grid, solar, load, circuit and plug power
climate       temperature, humidity, air quality, thermostats
security      cameras, motion, doors, leaks, locks
battery       every battery-level entity
system        NAS, network, backups, updates, hosts
critical      freezer, leak sensors, sump, smoke, door contacts
maintenance   filters, firmware updates, low batteries
```

## Rename priority

Do not mass-rename 1276 entities. Rename the user-facing entities that appear on
dashboards and in automations first.

| Current | Proposed |
|---|---|
| `sensor.freezer_temperature` | `sensor.garage_freezer_temperature` |
| `sensor.freezer_humidity` | `sensor.garage_freezer_humidity` |
| `sensor.garage_garage_fridge_sensor_garage_fridge_temperature` | `sensor.garage_fridge_temperature` |
| `sensor.garage_fridge_sensor_garage_fridge_humidity` | `sensor.garage_fridge_humidity` |
| `sensor.master_bedroom_temperature_and_humidity_temperature` | `sensor.master_bedroom_temperature` |
| `sensor.master_bedroom_temperature_and_humidity_battery_state` | `sensor.master_bedroom_climate_battery` |
| `sensor.girls_room_temperature_and_humidity_battery_state` | `sensor.girls_room_climate_battery` |
| `sensor.living_room_air_conditioner_filter_remaining_life` | `sensor.living_room_ac_filter_life` |
| `binary_sensor.second_floor_bathroom_water_leak_sensor_water_leak` | `binary_sensor.second_floor_bathroom_leak` |
| `binary_sensor.second_floor_bathroom_water_leak_sensor_battery_low` | `binary_sensor.second_floor_bathroom_leak_battery_low` |
| `sensor.smart_air_quality_monitor_304b95_h5106_pm25` | `sensor.<area>_air_quality_pm25` |
| `sensor.0x282c02bfffec3463_power` | `sensor.<area>_<plug>_power` |
| `light.0x001788010f...` | `light.<area>_<fixture>` |
| `media_player.office_tv_2` (Living Room) | `media_player.living_room_tv_2` or remove |

For MQTT devices, set the friendly name and device name in Zigbee2MQTT or the
publisher first. Home Assistant generates cleaner IDs from the new discovery
payload. For Frigate cameras, rename the camera in Frigate and let the
integration recreate entities.

## Dashboards

Use HA's sections view. Prefer built-in cards: area, tile, gauge,
history-graph, statistics-graph, entities, grid, markdown, and conditional.
Do not add a custom card dependency for the first pass.

### 1. Home (default)

- Presence: Kevin, Bethany, and home/away summary.
- Weather and time.
- Area cards for Living Room, Kitchen, Master Bedroom, Office, Garage.
- Quick controls: lights, climate, media.
- Security summary: leaks, doors, cameras, unavailable critical sensors.
- Energy summary: grid, solar, load.

### 2. Climate & Air

- Freezer and fridge gauges plus 24-hour history.
- Per-room temperature and humidity graphs.
- Six climate tiles.
- Air quality (PM2.5) and humidifiers.
- Battery levels for climate sensors.

### 3. Energy

- Grid, load, and solar power.
- AC current for living room, office, master, attic.
- Smart-plug power and energy: string lights, Christmas tree, Zigbee plugs.
- Top consumers and daily/monthly statistics.
- Battery-low maintenance list.

### 4. Security & Cameras

- Frigate camera cards for Attic 1-4.
- Person/motion/review status.
- Leak sensors and door/window contacts.
- Locks and garage doors when those entities exist.
- A markdown card listing unavailable security entities.

### 5. Garage & Appliances

- Freezer/fridge detail with history and alert thresholds.
- Washer/dryer (SmartThinQ) status.
- Roborock vacuum and maps.
- Printer supplies.

### 6. Media

- Speakers and TVs by room.
- Spotify and Denon AVR.
- Cast/Nest devices.
- Remove or hide duplicate TV entities.

### 7. Systems & Maintenance

- Synology DSM health and storage.
- Network (TP-Link Deco) status.
- Backups and Home Assistant updates.
- Frigate CPU, detection FPS, and skipped FPS.
- Full list of unavailable entities.
- Firmware and low-battery maintenance.

## Rollout order

1. **Clean up.** Remove the 112 Docker switches and their devices. Review
   unavailable discovery duplicates and delete the ones whose integrations are
   gone. Do not touch deliberate disabled entities.
2. **Assign areas.** Start with the 460 MQTT entities. Device-level assignment
   is fastest.
3. **Add labels** to the entities used by each planned dashboard.
4. **Rename** the top 30-40 user-facing entities, updating automations as you
   go.
5. **Build dashboards** in order: Home, Climate & Air, Security & Cameras,
   Energy, Garage & Appliances, Media, Systems.
6. **Add alerts** for freezer temperature, leaks, unavailable critical
   entities, and low batteries.

## Guardrails

- Rename in the Home Assistant UI so `unique_id` and history survive.
- Do not hand-edit `.storage` for routine renames.
- After renaming, update automations, scripts, and dashboards that reference the
  old `entity_id`.
- Keep `automations.yaml` and `scripts.yaml` UI-editable until they are migrated
  into Git separately.
- Back up `/config/.storage/core.entity_registry` and
  `core.device_registry` before any bulk registry cleanup.
- Keep the existing Map dashboard; it is still useful.

## Known gaps

- No `cover` or `lock` entities exist for the garage doors, only battery
  sensors. Dashboard control requires adding the door controller integration
  first.
- There is no solar energy total, only instantaneous solar power.
- Several Zigbee devices still expose raw hex entity IDs.
- The two Roborock map cameras should be separated from security cameras.
