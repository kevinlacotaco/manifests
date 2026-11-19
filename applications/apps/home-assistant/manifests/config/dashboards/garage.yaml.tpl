title: Garage & Appliances
views:
- title: Garage & Appliances
  path: garage
  icon: mdi:garage
  type: sections
  sections:
  - type: grid
    cards:
    - type: history-graph
      title: Freezer, fridge, and ambient temperature
      hours_to_show: 48
      entities:
      - entity: sensor.garage_freezer_temperature
      - entity: sensor.garage_fridge_temperature
      - entity: sensor.garage_ambient_temperature
  - type: grid
    cards:
    - type: history-graph
      title: Humidity
      hours_to_show: 48
      entities:
      - entity: sensor.garage_freezer_humidity
      - entity: sensor.garage_fridge_humidity
      - entity: sensor.garage_ambient_humidity
  - type: grid
    cards:
    - type: heading
      heading: Current readings
      icon: mdi:thermometer
    - type: tile
      entity: sensor.garage_freezer_temperature
    - type: tile
      entity: sensor.garage_fridge_temperature
    - type: tile
      entity: sensor.garage_ambient_temperature
  - type: grid
    cards:
    - type: entities
      title: Garage plug
      state_color: true
      entities:
      - entity: sensor.garage_plug_power
      - entity: sensor.garage_plug_energy
    - type: entities
      title: Doors
      state_color: true
      entities:
      - entity: binary_sensor.right_garage_door_battery_low
      - entity: binary_sensor.right_garage_door_contact
      - entity: binary_sensor.left_garage_door_contact
