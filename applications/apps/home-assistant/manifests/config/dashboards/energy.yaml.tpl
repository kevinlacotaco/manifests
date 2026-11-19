title: Energy
views:
- title: Energy
  path: energy
  icon: mdi:flash
  type: sections
  sections:
  - type: grid
    cards:
    - type: markdown
      content: "### Home demand"
    - type: tile
      entity: sensor.my_home_grid_power
    - type: tile
      entity: sensor.my_home_load_power
    - type: tile
      entity: sensor.my_home_solar_power
  - type: grid
    cards:
    - type: history-graph
      title: Grid, load, and solar
      hours_to_show: 48
      entities:
      - entity: sensor.my_home_grid_power
      - entity: sensor.my_home_load_power
      - entity: sensor.my_home_solar_power
  - type: grid
    cards:
    - type: entities
      title: Air conditioner energy
      state_color: true
      entities:
      - entity: sensor.living_room_air_conditioner_energy_current
      - entity: sensor.office_air_conditioner_energy_current
      - entity: sensor.master_air_conditioner_energy_current
      - entity: sensor.attic_ac_energy_current
  - type: grid
    cards:
    - type: entities
      title: Plugs and lights
      state_color: true
      entities:
      - entity: sensor.living_room_floor_light_1_power
      - entity: sensor.living_room_floor_light_2_power
      - entity: sensor.wiz_rgbw_tunable_710ac4_power
      - entity: sensor.wiz_rgbw_tunable_711fe4_power
      - entity: sensor.wiz_rgbw_tunable_712a38_power
      - entity: sensor.wiz_rgbw_tunable_71394c_power
      - entity: sensor.garage_plug_power
      - entity: sensor.garage_plug_energy
      - entity: sensor.madisons_bedroom_plug_power
      - entity: sensor.madisons_bedroom_plug_energy
      - entity: sensor.attic_plug_power
      - entity: sensor.attic_plug_energy
      - entity: sensor.string_lights_energy
      - entity: sensor.string_lights_power
      - entity: sensor.christmas_tree_energy
      - entity: sensor.christmas_tree_power
      - entity: sensor.bonus_room_plug_power
      - entity: sensor.bonus_room_plug_energy
