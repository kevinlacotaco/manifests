title: Home
views:
- title: Home
  path: home
  icon: mdi:home
  type: sections
  sections:
  - type: grid
    cards:
    - type: heading
      heading: Climate
      icon: mdi:thermometer
    - type: tile
      entity: climate.living_room_air_conditioner
    - type: tile
      entity: climate.office_air_conditioner
    - type: tile
      entity: climate.master_air_conditioner
    - type: tile
      entity: climate.attic_ac
    - type: tile
      entity: humidifier.willy_s_humidifier
    - type: tile
      entity: humidifier.master_bedroom_humidifier
    - type: tile
      entity: humidifier.girls_humidifier
  - type: grid
    cards:
    - type: heading
      heading: Energy
      icon: mdi:flash
    - type: tile
      entity: sensor.my_home_grid_power
    - type: tile
      entity: sensor.my_home_load_power
    - type: tile
      entity: sensor.my_home_solar_power
  - type: grid
    cards:
    - type: heading
      heading: Security
      icon: mdi:shield-home
    - type: tile
      entity: binary_sensor.utility_sink_leak
    - type: tile
      entity: binary_sensor.first_floor_bathroom_sink_water_leak
    - type: tile
      entity: binary_sensor.kitchen_sink_leak
    - type: tile
      entity: binary_sensor.second_floor_bathroom_leak
  - type: grid
    cards:
    - type: heading
      heading: Garage
      icon: mdi:garage
    - type: tile
      entity: sensor.garage_freezer_temperature
    - type: tile
      entity: sensor.garage_fridge_temperature
    - type: tile
      entity: sensor.garage_ambient_temperature
  - type: grid
    cards:
    - type: heading
      heading: Media
      icon: mdi:speaker
    - type: media-control
      entity: media_player.living_room_tv
    - type: media-control
      entity: media_player.attic_tv
    - type: media-control
      entity: media_player.office_speaker
  - type: grid
    cards:
    - type: heading
      heading: Systems
      icon: mdi:server
    - type: tile
      entity: sensor.ironhide_cpu_usage
    - type: tile
      entity: sensor.ironhide_memory_usage
    - type: tile
      entity: sensor.grapple_cpu_usage
    - type: tile
      entity: sensor.grapple_memory_usage
